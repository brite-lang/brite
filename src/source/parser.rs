//! Parses a stream of tokens into an Abstract Syntax Tree (AST). We designed our parser with error
//! recovery in mind! The parser should be able to process any text document thrown at it. The error
//! recovery design is partly inspired by [Microsoft’s error tolerant PHP parser][1] design.
//!
//! Our goal for the error recovery behavior is:
//!
//! 1. Don’t over-complicate the parser. We’d rather the parser be easily extendable then have super
//!    robust error recovery.
//! 2. Don’t go to great lengths to produce some reasonable AST for code immediately around a
//!    syntax error. We’d rather show one syntax error than five type checker errors because we
//!    parsed some nonsense AST.
//! 3. Do parse surrounding declarations. That way we may continue providing services like
//!    hover types.
//!
//! [1]: https://github.com/Microsoft/tolerant-php-parser/blob/master/docs/HowItWorks.md

use super::ast::*;
use super::identifier::Keyword;
use super::lexer::Lexer;
use super::token::*;
use std::collections::HashMap;

#[derive(Debug)]
enum Never {}

/// Parses a stream of tokens into an Abstract Syntax Tree (AST).
pub struct Parser<'a> {
    /// The lexer our parser uses to generate tokens. The lexer owns a diagnostics struct that we
    /// also use in our parser.
    lexer: Lexer<'a>,
    /// Glyphs at which our parser will recover from an error.
    recoverable: HashMap<Glyph, usize>,
}

impl<'a> Parser<'a> {
    fn new(lexer: Lexer<'a>) -> Self {
        Parser {
            lexer,
            recoverable: HashMap::new(),
        }
    }

    /// Parses a module from a token stream consuming _all_ tokens in the stream.
    pub fn parse(lexer: Lexer<'a>) -> Module {
        let mut parser = Parser::new(lexer);
        parser.parse_module().unwrap()
    }

    fn parse_module(&mut self) -> Result<Module, Never> {
        // Parse all the items we can until we reach the end.
        let items = self.parse_item_list(Token::is_end)?;
        // Consume the ending token. We need it for our AST.
        let end = match self.lexer.advance() {
            Token::End(end) => end,
            _ => unreachable!(),
        };
        // Assert that our recover map is empty.
        debug_assert!(self.recoverable.is_empty());
        // Return the module AST.
        Ok(Module::new(items, end))
    }

    fn parse_block(&mut self) -> Result<Block, Never> {
        let brace_left = self.parse_glyph(Glyph::BraceLeft)?;
        let items = self.parse_item_list(|token| token.is_glyph(Glyph::BraceRight))?;
        let brace_right = self.parse_glyph(Glyph::BraceRight)?;
        Ok(Block::new(brace_left, items, brace_right))
    }

    fn parse_item_list<F>(&mut self, until: F) -> Result<Vec<Item>, Never>
    where
        F: Fn(&Token) -> bool,
    {
        let mut items = Vec::new();
        while !until(self.lexer.lookahead()) {
            let item = self.parse_item()?;
            items.push(item);
        }
        items.shrink_to_fit();
        Ok(items)
    }

    fn parse_item(&mut self) -> Result<Item, Never> {}

    fn parse_statement(&mut self) -> Result<Statement, Never> {
        self.recover_at(Glyph::Semicolon, Self::actually_parse_statement)
    }

    fn actually_parse_statement(&mut self) -> Result<Statement, Never> {
        // Parse `BindingStatement`.
        if let Some(let_) = self.try_parse_glyph(Glyph::Keyword(Keyword::Let)) {
            let pattern = self.recover_at(Glyph::Equals, Self::parse_pattern);
            let equals = self.parse_glyph(Glyph::Equals);
            let value = self.parse_expression();
            let semicolon = self.try_parse_glyph(Glyph::Semicolon);
            let binding = BindingStatement::new(let_, pattern, equals, value, semicolon);
            return Ok(Statement::Binding(binding).into());
        }

        // Parse `ExpressionStatement` if we couldn’t parse any other statement.
        let expression = self.parse_expression();
        let semicolon = self.try_parse_glyph(Glyph::Semicolon);
        let statement = ExpressionStatement::new(expression, semicolon);
        Ok(Statement::Expression(statement).into())
    }

    fn parse_expression(&mut self) -> Result<Expression, Never> {
        let expression = match self.lexer.advance() {
            // Parse `VariableExpression`.
            Token::Identifier(token) => Expression::Variable(VariableExpression::new(token)),

            // Parse `NumberConstant`.
            Token::Number(token) => {
                let constant = NumberConstant::new(token);
                Expression::Constant(Constant::Number(constant))
            }

            Token::Glyph(token) => match token.glyph() {
                // Parse true `BooleanConstant`.
                Glyph::Keyword(Keyword::True) => {
                    let constant = BooleanConstant::new(token, true);
                    Expression::Constant(Constant::Boolean(constant))
                }

                // Parse false `BooleanConstant`.
                Glyph::Keyword(Keyword::False) => {
                    let constant = BooleanConstant::new(token, false);
                    Expression::Constant(Constant::Boolean(constant))
                }

                // Parse `ConditionalExpression`.
                Glyph::Keyword(Keyword::If) => {
                    let if_ = token;
                    let test = self.parse_expression()?;
                    let consequent = self.parse_block()?;
                    let alternate =
                        if let Some(else_) = self.try_parse_glyph(Glyph::Keyword(Keyword::Else)) {
                            let block = self.parse_block()?;
                            Some(ConditionalExpressionAlternate::new(else_, block))
                        } else {
                            None
                        };
                    let conditional = ConditionalExpression::new(if_, test, consequent, alternate);
                    Expression::Conditional(Box::new(conditional))
                }

                // Parse `BlockExpression`.
                Glyph::Keyword(Keyword::Do) => {
                    let do_ = token;
                    let block = self.parse_block()?;
                    Expression::Block(BlockExpression::new(do_, block))
                }

                // Parse `WrappedExpression`.
                Glyph::ParenLeft => {
                    let paren_left = token;
                    let expression = self.parse_expression()?;
                    let paren_right = self.parse_glyph(Glyph::ParenRight)?;
                    let wrapped = WrappedExpression::new(paren_left, expression, paren_right);
                    Expression::Wrapped(Box::new(wrapped))
                }

                _ => unimplemented!(),
            },

            _ => unimplemented!(),
        };

        // Parse some expression extensions.
        let mut expression = expression;
        loop {
            // Parse `PropertyExpression`.
            if let Some(dot) = self.try_parse_glyph(Glyph::Dot) {
                let property = self.parse_identifier()?;
                let member = PropertyExpression::new(expression, dot, property);
                expression = Expression::Property(Box::new(member));
                continue;
            }

            // Parse `CallExpression`.
            if let Some(paren_left) = self.try_parse_glyph_on_same_line(Glyph::ParenLeft) {
                let arguments = self.parse_comma_list(Parser::parse_expression, |token| {
                    token.is_glyph(Glyph::ParenRight)
                })?;
                let paren_right = self.parse_glyph(Glyph::ParenRight)?;
                let call = CallExpression::new(expression, paren_left, arguments, paren_right);
                expression = Expression::Call(Box::new(call));
                continue;
            }

            // If we could not parse any extension break out of the loop.
            break;
        }

        Ok(expression)
    }

    fn parse_pattern(&mut self) -> Result<Pattern, Never> {
        match self.lexer.advance() {
            // Parse a `VariablePattern`.
            Token::Identifier(identifier) => {
                let variable = VariablePattern::new(identifier);
                Ok(Pattern::Variable(variable))
            }

            Token::Glyph(token) => match token.glyph() {
                // Parse a `HolePattern`.
                Glyph::Underscore => Ok(Pattern::Hole(HolePattern::new(token))),

                _ => unimplemented!(),
            },

            _ => unimplemented!(),
        }
    }

    /// Parses a list of comma separated items until a specified token. The list may optionally have
    /// trailing commas.
    fn parse_comma_list<T, F, G>(
        &mut self,
        parse_item: F,
        until: G,
    ) -> Result<Vec<CommaListItem<T>>, Never>
    where
        F: Fn(&mut Self) -> Result<T, Never>,
        G: Fn(&Token) -> bool,
    {
        let mut items = Vec::new();

        // Keep parsing items until we find the token we want to stop at.
        while !until(self.lexer.lookahead()) {
            let item = parse_item(self)?;

            // If the next glyph is a comma then parse it and try to parse another item. If this is
            // a trailing comma then the while loop’s condition will fail and we won’t parse
            // another item.
            if let Some(comma) = self.try_parse_glyph(Glyph::Comma) {
                items.push(CommaListItem::new(item, Some(comma)));
                continue;
            }

            // If there is no comma, but we do see our final token then add our item and break out
            // of the loop.
            if until(self.lexer.lookahead()) {
                items.push(CommaListItem::new(item, None));
                break;
            }

            // Otherwise, we have an error.
            unimplemented!();
        }

        items.shrink_to_fit();
        Ok(items)
    }

    /* ─── Utilities ──────────────────────────────────────────────────────────────────────────── */

    /// Tries to parse the provided glyph. If we could not parse the provided token then return
    /// `None` and don’t advance the lexer. Otherwise advance the lexer and return the parsed token.
    fn try_parse_glyph(&mut self, glyph: Glyph) -> Option<GlyphToken> {
        match self.lexer.lookahead() {
            Token::Glyph(token) if token.glyph() == &glyph => match self.lexer.advance() {
                Token::Glyph(token) => Some(token),
                _ => unreachable!(),
            },
            _ => None,
        }
    }

    /// Tries to parse the provided glyph, but _only_ if that glyph is on the same line as our
    /// current lexer position. If we could not parse the provided token then return `None` and
    /// don’t advance the lexer. Otherwise advance the lexer and return the parsed token.
    fn try_parse_glyph_on_same_line(&mut self, glyph: Glyph) -> Option<GlyphToken> {
        match self.lexer.lookahead_on_same_line() {
            Some(Token::Glyph(token)) if token.glyph() == &glyph => match self.lexer.advance() {
                Token::Glyph(token) => Some(token),
                _ => unreachable!(),
            },
            _ => None,
        }
    }

    /// Parses the provided glyph or fails if the next token is not the provided glyph. Always
    /// advances the lexer.
    fn parse_glyph(&mut self, glyph: Glyph) -> Result<GlyphToken, Never> {
        match self.lexer.advance() {
            Token::Glyph(token) => {
                if token.glyph() == &glyph {
                    return Ok(token);
                }
            }
            _ => {}
        }
        unimplemented!()
    }

    /// Parses an identifier or fails if the next token is not an identifier. Always advances
    /// the lexer.
    fn parse_identifier(&mut self) -> Result<IdentifierToken, Never> {
        match self.lexer.advance() {
            Token::Identifier(token) => Ok(token),
            _ => unimplemented!(),
        }
    }

    /* ─── Error Recovery ─────────────────────────────────────────────────────────────────────── */

    /// If a parse error is encountered while executing the provided function we will skip tokens
    /// trying to get a successful parse. That is until we reach one of the tokens we were told to
    /// recover from. This is how we introduce a glyph to be recovered from into scope.
    fn recover_at<T>(&mut self, glyph: Glyph, f: impl FnOnce(&mut Self) -> T) -> T {
        if let Some(n) = self.recoverable.get_mut(&glyph) {
            *n += 1;
        } else {
            self.recoverable.insert(glyph, 1);
        }
        let result = f(self);
        if let Some(n) = self.recoverable.get_mut(&glyph) {
            *n -= 1;
            if *n == 0 {
                self.recoverable.remove(&glyph);
            }
        }
        result
    }

    fn recover<Node>(&mut self, parse: impl Fn(&mut Self) -> Option<Node>) -> Result<Node, Never> {
        // Shortcut if there are no errors and we can successfully parse our node.
        if let Some(node) = parse(self) {
            return Ok(node);
        }

        // Collect all the nodes we’ll skip when trying to recover.
        let mut skipped = Vec::new();

        // Skip tokens in the lexer until we:
        //
        // 1. Reach the end at which we will immediately recover.
        // 2. Reach a recoverable token at which we will immediately recover.
        // 3. Can finally parse a node.
        loop {
            let recover = match self.lexer.lookahead() {
                Token::End(_) => true,
                Token::Glyph(token) if self.recoverable.contains_key(&token.glyph()) => true,
                _ => false,
            };
            if recover {
                /* error */
                unimplemented!()
            } else {
                skipped.push(self.lexer.advance());
                if let Some(node) = parse(self) {
                    /* skipped */
                    unimplemented!()
                }
            }
        }
    }
}
