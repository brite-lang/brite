//! Diagnostic messages are our primary way to communicate with the user. We better be really sure
//! our messages are good.
//!
//! In the future, we should consider consulting a copy editor to professionalize our error message
//! style. We may also want to consider running A/B tests.
//!
//! # Style Guide
//!
//! What makes a good error message? These guides are designed to produce the clearest message
//! possible. Follow these guides to create good, consistent, error messages.
//!
//! - Keep diagnostic messages short. Preferably a single, clear, sentence. This format works
//!   best for all our target editors. Consider VSCode which uses a hover dialog for viewing
//!   errors inline and a “problems” panel to view all errors in a project. Short single-line
//!   messages work best in both of these locations.
//!
//! - 80% of the time the fix is obvious to human and computer so provide a direct error message.
//!   20% of the time the error won’t be obvious to the human so provide a message which is _not_
//!   misleading and gives the human enough information to step through their program and find the
//!   fix which might involve making tradeoffs a computer couldn’t understand in their program.
//!   Never give a human a misleading an error message, they’ll spend more time on the message then
//!   on their program.
//!
//! - Trust that the programmer is clever unless shown otherwise. Prefer error messages which are
//!   always short and true to error messages which are long and misleading/false. If the
//!   programmer is clever and you’ve given them enough tools (error messages, extra references, IDE
//!   tools like hover types) the clever programmer should be able to deduce the real problem in
//!   their code. If it is shown the programmer is not clever enough to solve the error on their own
//!   with the given error message then consider giving them a better error message.
//!
//! - Use correct English grammar. It can be hard to make a program which produces correct English
//!   grammar. If you must, consult a spellchecker.
//!
//! - Write messages in first-person plural. That is, use “we”. For example “we see an error”.
//!   This personifies our type checker as a team of people looking for bugs in the programmer’s
//!   code. By personifying our type checker error messages feel like a dialogue. Elm’s error
//!   messages are famous for using first-person. I (Caleb) always found messages like “I found an
//!   error” to be a bit annoying since the type checker is certainly not a person nor is it built
//!   by a single person. Hopefully “we” will be a nice compromise.
//!
//! - When speaking, present tense instead of past tense. Instead of “we found” say “we see”. An
//!   error in the programmer’s code is not a point in time, but rather a state in which the code
//!   will remain until the bug is fixed. While yes, the type checker runs at discrete points in
//!   time we want to give the user the perception that Brite is alive and reacting to their input.
//!   Not spinning in a background thread and then spitting out errors every once in a while.
//!
//! - Use language the programmer will understand. Not language the compiler understands. Words
//!   like “identifier”, “token”, and “expression” are compiler speak. Instead of compiler speak
//!   like “identifier” use a phrase like “variable name”.
//!
//! - Any text that might be written in code should use inline code markup formatting from the
//!   `Markup` object. This should then be rendered as inline code blocks by diagnostic
//!   message renderers.
//!
//! - If you use quotes, make sure they are curly quotes. For instance “phrase” instead
//!   of "phrase". Same for single quotes. For instance ‘phrase’ instead of 'phrase'. Unless you
//!   are talking about quotes inside of code.
//!
//! - The message in related information should be present somewhere in the main message of a
//!   diagnostic. It’s like the related information is a “link” to something mentioned in
//!   the message. We can’t be sure of all the ways an IDE might choose to display
//!   related information.
//!
//! ## Helpful Tools
//!
//! Some tools we find are helpful when designing on an error message.
//!
//! - [Grammarly](https://www.grammarly.com) for confirming your grammar is correct.
//! - [Hemingway Editor](http://www.hemingwayapp.com) for reducing the complexity of your writing.

use crate::language::{Constant, LogicalOperator, PrefixOperator};
use crate::parser::{Document, Glyph, Identifier, IdentifierKeyword, Position, Range, Token};
use crate::utils::markup::{Markup, MarkupCode};
use std::fmt::{self, Write};
use std::ops::Deref;
use std::rc::Rc;

/// A diagnostic is some message presented to the user about their program. Diagnostics contain a
/// range of characters which the diagnostic points to. Diagnostics are only valid in the scope of
/// some resource since while they contain a range they do not contain the document that range
/// applies to.
///
/// Our diagnostic format is based on the [Language Server Protocol][1].
///
/// [1]: https://microsoft.github.io/language-server-protocol/specification
#[derive(Debug)]
pub struct Diagnostic {
    /// The range of our diagnostic.
    pub range: Range,
    /// A representation of every possible diagnostic message.
    message: DiagnosticMessage,
}

/// The diagnostic message. Includes the severity of the message. Each diagnostic may have some
/// related information.
///
/// Diagnostic messages may not be constructed outside of this module. We always construct and
/// report a diagnostic at the same time as well.
#[derive(Debug)]
enum DiagnosticMessage {
    /// Error diagnostics must be resolved by the programmer. Error diagnostics will prevent the
    /// program from being deployed. However, the program may still run in development, but
    /// executing a program with errors will result in Undefined Behavior.
    Error(ErrorDiagnosticMessage),
    /// Warning diagnostics may optionally be resolved by the programmer. They exist to highlight
    /// code which is technically correct but might be suboptimal. Warnings will not block
    /// deployment of a program by default. However, it is strongly recommended that warnings
    /// be fixed.
    #[allow(dead_code)]
    Warning(WarningDiagnosticMessage),
    /// Useful information about a user’s program that does not need to be changed. Unlike a warning
    /// where we are recommending a code change.
    #[allow(dead_code)]
    Info(InfoDiagnosticMessage),
}

#[derive(Debug)]
enum ErrorDiagnosticMessage {
    /// The parser ran into syntax it did not recognize.
    UnexpectedSyntax {
        unexpected: UnexpectedSyntax,
        expected: ExpectedSyntax,
    },
    /// The parser ran into the end of the source document unexpectedly.
    UnexpectedEnding { expected: ExpectedSyntax },
    /// Could not find a declaration for an identifier.
    IdentifierNotFound { identifier: Identifier },
    /// A declaration with this name already exists.
    DeclarationNameAlreadyUsed {
        identifier: Identifier,
        declaration_range: Range,
    },
    /// While trying to type check a declaration we ended up checking ourselves.
    DeclarationCycleDetected {
        identifier: Identifier,
        declaration_range: Range,
    },
    /// Tried to extend a declaration which is not a base class.
    CanOnlyExtendBaseClass {
        identifier: Identifier,
        declaration_range: Range,
    },
    /// We found two types that were incompatible with one another during subtyping.
    IncompatibleTypes {
        operation: OperationSnippet,
        range1: Range,
        snippet1: TypeKindSnippet,
        range2: Range,
        snippet2: TypeKindSnippet,
    },
    /// We found two functions that had different parameter list lengths.
    IncompatibleFunctionParameterLengths {
        operation: OperationSnippet,
        range1: Range,
        len1: usize,
        range2: Range,
        len2: usize,
    },
    /// We found a function parameter that needs a type annotation since we can’t infer one.
    MissingFunctionParameterType { pattern: PatternSnippet },
    /// We found the programmer trying to call a type that is not a function.
    CannotCall {
        callee_range: Range,
        callee_type: TypeKindSnippet,
    },
}

#[derive(Debug)]
enum WarningDiagnosticMessage {}

#[derive(Debug)]
enum InfoDiagnosticMessage {}

/// Some syntax the Brite parser did not expect.
#[derive(Debug)]
pub enum UnexpectedSyntax {
    /// An unexpected glyph.
    Glyph(Glyph),
    /// An unexpected identifier.
    Identifier,
    /// An unexpected number.
    Number,
    /// An unexpected character.
    Char(char),
}

/// Some syntax the Brite expected but did not receive.
#[derive(Debug)]
pub enum ExpectedSyntax {
    /// Expected a particular glyph.
    Glyph(Glyph),
    /// Expected an identifier.
    Identifier,
    /// Expected an identifier keyword.
    IdentifierKeyword(IdentifierKeyword),
    /// Expected the end of a block comment.
    BlockCommentEnd,
    /// Expected a decimal digit.
    DecimalDigit,
    /// Expected a binary digit.
    BinaryDigit,
    /// Expected a hexadecimal digit.
    HexadecimalDigit,
    /// Expected a declaration.
    Declaration,
    /// Expected a class member.
    ClassMember,
    /// Expected a statement.
    Statement,
    /// Expected an expression.
    Expression,
    /// Expected a pattern.
    Pattern,
    /// Expected a type.
    Type,
}

/// A snippet describing some operation that we were trying to perform when a diagnostic occurred.
#[derive(Clone, Debug)]
pub enum OperationSnippet {
    /// An annotated expression failed to type check.
    ExpressionAnnotation(ExpressionSnippet),
    /// An annotated binding statement failed to type check.
    BindingStatementAnnotation(PatternSnippet, ExpressionSnippet),
    /// An annotated function return type failed to type check.
    FunctionReturnAnnotation(Option<StatementSnippet>),
    /// Calling a function failed to type check.
    FunctionCall(ExpressionSnippet),
    /// Some use of an operator failed to type check.
    OperatorExpression(OperatorSnippet),
}

/// A snippet describing any operator we might use in Brite programs.
#[derive(Clone, Debug)]
pub enum OperatorSnippet {
    /// `!`
    Not,
    /// `&&`
    And,
    /// `||`
    Or,
}

/// A snippet of some type for error message printing.
#[derive(Debug)]
pub enum TypeKindSnippet {
    /// The never type.
    Never,
    /// The void type.
    Void,
    /// The boolean type.
    Boolean,
    /// The number type.
    Number,
    /// The integer type.
    Integer,
    /// The float type.
    Float,
    /// A function type.
    Function,
}

/// A snippet of a [`Vec`]. May contain up to 2 items.
#[derive(Clone, Debug)]
pub enum VecSnippet<Item> {
    Vec0,
    Vec1(Item),
    Vec2(Item, Item),
    VecN(Item, Item),
}

impl<Item> VecSnippet<Item> {
    pub fn from_iter(mut iter: impl Iterator<Item = Item>) -> VecSnippet<Item>
    where
        Item: Clone,
    {
        let mut vec = VecSnippet::Vec0;

        while let Some(next_item) = iter.next() {
            match vec {
                VecSnippet::Vec0 => vec = VecSnippet::Vec1(next_item),
                VecSnippet::Vec1(item1) => vec = VecSnippet::Vec2(item1, next_item),
                VecSnippet::Vec2(item1, item2) | VecSnippet::VecN(item1, item2) => {
                    vec = VecSnippet::VecN(item1, item2);
                    break;
                }
            }
        }

        vec
    }
}

/// A snippet of some statement for error message printing.
#[derive(Clone, Debug)]
pub enum StatementSnippet {
    /// Some expression.
    Expression(ExpressionSnippet),
    // Some statement that binds a pattern in our current scope.
    Binding(PatternSnippet, ExpressionSnippet),
}

/// A snippet of some expression for error message printing. We try to keep the snippet small. A
/// mere description of the full expression.
#[derive(Clone, Debug)]
pub enum ExpressionSnippet {
    /// Some constant value in the program.
    Constant(Constant),
    /// A reference to some value in the program.
    Reference(Identifier),
    /// A function expression. We only keep some of the parameters in the function
    /// expression snippet.
    Function(VecSnippet<PatternSnippet>),
    /// A call expression. We only remember the callee.
    Call(Box<ExpressionSnippet>),
    /// Some expression using a prefix operator.
    Prefix(PrefixOperator, Box<ExpressionSnippet>),
    /// Some infix expression using a logical operator.
    Logical(
        Box<ExpressionSnippet>,
        LogicalOperator,
        Box<ExpressionSnippet>,
    ),
    /// A block expression which contains some statements.
    Block,
}

/// A snippet of some pattern for error message printing.
#[derive(Clone, Debug)]
pub enum PatternSnippet {
    /// A binding for some value in the program.
    Binding(Identifier),
}

impl Diagnostic {
    fn new(range: Range, message: DiagnosticMessage) -> Self {
        Diagnostic { range, message }
    }

    fn error(range: Range, message: ErrorDiagnosticMessage) -> Self {
        Self::new(range, DiagnosticMessage::Error(message))
    }

    /// The parser ran into syntax it did not recognize.
    pub fn unexpected_syntax(
        range: Range,
        unexpected: UnexpectedSyntax,
        expected: ExpectedSyntax,
    ) -> Self {
        Self::error(
            range,
            ErrorDiagnosticMessage::UnexpectedSyntax {
                unexpected,
                expected,
            },
        )
    }

    /// The parser ran into a character it did not recognize.
    pub fn unexpected_char(start: Position, unexpected: char, expected: ExpectedSyntax) -> Self {
        Self::unexpected_syntax(
            Range::single_char(start, unexpected),
            UnexpectedSyntax::Char(unexpected),
            expected,
        )
    }

    /// The parser ran into a token it did not recognize.
    pub fn unexpected_token(token: &Token, expected: ExpectedSyntax) -> Self {
        Self::unexpected_syntax(token.range, token.unexpected(), expected)
    }

    /// The parser ran into the end of the source document unexpectedly.
    pub fn unexpected_ending(position: Position, expected: ExpectedSyntax) -> Self {
        Self::error(
            Range::position(position),
            ErrorDiagnosticMessage::UnexpectedEnding { expected },
        )
    }

    /// Could not find a declaration for an identifier.
    pub fn identifier_not_found(range: Range, identifier: Identifier) -> Self {
        Self::error(
            range,
            ErrorDiagnosticMessage::IdentifierNotFound { identifier },
        )
    }

    /// A declaration with this name already exists.
    ///
    /// The first range is the range of the duplicated name. The second range is the range of the
    /// declaration that was already declared.
    pub fn declaration_name_already_used(
        range: Range,
        identifier: Identifier,
        declaration_range: Range,
    ) -> Self {
        Self::error(
            range,
            ErrorDiagnosticMessage::DeclarationNameAlreadyUsed {
                identifier,
                declaration_range,
            },
        )
    }

    /// While trying to type check a declaration we ended up checking ourselves.
    ///
    /// The first range is the range of the declaration which references itself.
    pub fn declaration_cycle_detected(
        range: Range,
        identifier: Identifier,
        declaration_range: Range,
    ) -> Self {
        Self::error(
            range,
            ErrorDiagnosticMessage::DeclarationCycleDetected {
                identifier,
                declaration_range,
            },
        )
    }

    /// Tried to extend a declaration which is not a base class.
    ///
    /// The first range is the range of the bad extends name. The second range is the range of the
    /// declaration that is not a base class.
    pub fn can_only_extend_base_class(
        range: Range,
        identifier: Identifier,
        declaration_range: Range,
    ) -> Self {
        Self::error(
            range,
            ErrorDiagnosticMessage::CanOnlyExtendBaseClass {
                identifier,
                declaration_range,
            },
        )
    }

    /// We found two types that were incompatible with one another during subtyping.
    ///
    /// We will report the error at the first range. The second and third ranges will be used as
    /// related locations if the information is necessary.
    pub fn incompatible_types(
        range: Range,
        operation: OperationSnippet,
        (range1, snippet1): (Range, TypeKindSnippet),
        (range2, snippet2): (Range, TypeKindSnippet),
    ) -> Self {
        Self::error(
            range,
            ErrorDiagnosticMessage::IncompatibleTypes {
                operation,
                range1,
                snippet1,
                range2,
                snippet2,
            },
        )
    }

    /// We found two functions that had different parameter list lengths.
    pub fn incompatible_function_parameter_lengths(
        range: Range,
        operation: OperationSnippet,
        (range1, len1): (Range, usize),
        (range2, len2): (Range, usize),
    ) -> Self {
        Self::error(
            range,
            ErrorDiagnosticMessage::IncompatibleFunctionParameterLengths {
                operation,
                range1,
                len1,
                range2,
                len2,
            },
        )
    }

    /// We found a pattern that needs a type annotation since we can’t infer one.
    pub fn missing_function_parameter_type(range: Range, pattern: PatternSnippet) -> Self {
        Self::error(
            range,
            ErrorDiagnosticMessage::MissingFunctionParameterType { pattern },
        )
    }

    /// We found the programmer trying to call a type that is not a function.
    pub fn cannot_call(range: Range, callee_range: Range, callee_type: TypeKindSnippet) -> Self {
        Self::error(
            range,
            ErrorDiagnosticMessage::CannotCall {
                callee_range,
                callee_type,
            },
        )
    }
}

/// Related information for a diagnostic in case the primary message was not enough. Most
/// importantly, related information carries a location so we can point to source code which
/// contributed to an error.
///
/// See related information in the [Language Server Protocol (LSP) Specification][1].
///
/// See an example of [related information rendered in VSCode][2].
///
/// [1]: https://microsoft.github.io/language-server-protocol/specification
/// [2]: https://code.visualstudio.com/updates/v1_22#_related-information-in-errors-and-warnings
struct DiagnosticRelatedInformation {
    range: Range,
    message: Markup,
}

impl Diagnostic {
    /// Creates a human readable diagnostic message for a given diagnostic. Also may create some
    /// related information regarding the error. Remember that this generates a new message every
    /// time it is called instead of fetching a pre-generated message.
    fn message(&self) -> (Markup, Vec<DiagnosticRelatedInformation>) {
        match &self.message {
            DiagnosticMessage::Error(message) => self.error_message(message).unwrap(),
            DiagnosticMessage::Warning(_) => unreachable!(),
            DiagnosticMessage::Info(_) => unreachable!(),
        }
    }

    fn error_message(
        &self,
        error_message: &ErrorDiagnosticMessage,
    ) -> Result<(Markup, Vec<DiagnosticRelatedInformation>), fmt::Error> {
        match error_message {
            // Thought and care that went into this error message:
            //
            // - When designing this message we started with “Unexpected character `%`. Expected
            //   expression.” and ended with the message “We found `%` when we wanted an
            //   expression.” The latter uses smaller words. It isn’t abrupt. It personifies the
            //   type checker with “we”.
            //
            // - The message starts with what we wanted and ends with what we found. Instead of
            //   saying “We found `%` when we expected an expression.” the message reads “We wanted
            //   an expression but we found `%`.” This gets to the resolution of the error message
            //   faster. In most cases the programmer only really needs to see “We wanted an
            //   expression” to know the solution.
            //
            // - Instead of “we found a `%` character” we print the message as “we found `%`”. The
            //   latter is shorter. It is also very hard to choose correctly between “a” and “an”
            //   for arbitrary user input. For example this is wrong “a `=` character” since `=` is
            //   pronounced “equals” which starts with a vowel sound. It should be “an `=`
            //   character”. We are unaware of a way to correctly guess the pronunciation people use
            //   for glyphs in general.
            //
            // - For unexpected tokens when we expected a pattern we say “We found `=` when we
            //   wanted a variable name.” because the word “pattern” is compiler speak. Even though
            //   patterns can be more than a variable name, 80% of the time the programmer will
            //   write a variable name.
            ErrorDiagnosticMessage::UnexpectedSyntax {
                unexpected,
                expected,
            } => {
                let mut message = Markup::new();
                write!(message, "We want ")?;
                expected.print(&mut message)?;
                match unexpected {
                    UnexpectedSyntax::Char('\n') | UnexpectedSyntax::Char('\r') => {
                        write!(message, " but the line ends.")?
                    }
                    _ => {
                        write!(message, " but we have ")?;
                        unexpected.print(&mut message)?;
                        write!(message, ".")?;
                    }
                }
                Ok((message, Vec::new()))
            }

            // Follows the same format as the unexpected token error. Except instead of saying “we
            // found the end of the file” we say “We wanted an expression but the file ended.” This
            // is less abstract than saying “we found the file’s end.” The end of a file is an
            // abstract concept and so finding the end of a file is a bit weird. It makes sense from
            // the perspective of parsing but not from the user’s perspective which we are
            // designing for.
            ErrorDiagnosticMessage::UnexpectedEnding { expected } => {
                let mut message = Markup::new();
                write!(message, "We want ")?;
                expected.print(&mut message)?;
                write!(message, " but the file ends.")?;
                Ok((message, Vec::new()))
            }

            // We tell the user directly that the name they were looking for is missing. “does not
            // exist” is a bit harsh. It might also be untrue from the user’s point of view. The
            // variable could exist in a different scope or with a small mis-spelling. Instead we
            // use “can not find” which is simple and to the point.
            //
            // TODO: Propose names that are spelled similarly as “did you mean `x`”?
            ErrorDiagnosticMessage::IdentifierNotFound { identifier } => {
                let mut message = Markup::new();
                write!(message, "Can not find ")?;
                write!(message.code(), "{}", identifier.as_str())?;
                write!(message, ".")?;
                Ok((message, Vec::new()))
            }

            // Tell the programmer that they can not use their name a second time. We also make sure
            // that we point out the first place they use the declaration name in related
            // information in case the programmer is confused.
            ErrorDiagnosticMessage::DeclarationNameAlreadyUsed {
                identifier,
                declaration_range,
            } => {
                let mut message = Markup::new();
                write!(message, "Can not use the name ")?;
                write!(message.code(), "{}", identifier.as_str())?;
                write!(message, " again.")?;
                let mut related_information = Vec::new();
                {
                    let mut message = Markup::new();
                    write!(message.code(), "{}", identifier.as_str())?;
                    related_information.push(DiagnosticRelatedInformation {
                        range: *declaration_range,
                        message: message,
                    });
                }
                Ok((message, related_information))
            }

            // This error usually happens when there is a class extension cycle. However, in the
            // type checker implementation, theoretically it could happen anywhere we need
            // information from a declaration. So we need an error message that is sufficiently
            // general which means we can’t say the word “class” even though that’s the most common
            // use case.
            //
            // We choose to use the range where we detected the cycle as the range for this
            // diagnostic and reference the declaration in related information. This way the user
            // can see where the cycle is formed.
            //
            // Unfortunately because a cycle is, well, circular, it’s kind of arbitrary where we end
            // up breaking a cycle.
            ErrorDiagnosticMessage::DeclarationCycleDetected {
                identifier,
                declaration_range,
            } => {
                let mut message = Markup::new();
                write!(message, "Can not use ")?;
                write!(message.code(), "{}", identifier.as_str())?;
                write!(message, " because it would create a circular reference.")?;
                let mut related_information = Vec::new();
                {
                    let mut message = Markup::new();
                    write!(message.code(), "{}", identifier.as_str())?;
                    related_information.push(DiagnosticRelatedInformation {
                        range: *declaration_range,
                        message: message,
                    });
                }
                Ok((message, related_information))
            }

            // Tell the programmer they can’t extend the declaration because it is not a base class.
            // Make sure we point to the declaration in related information so the programmer can
            // see that, indeed, the declaration that is not a base class.
            ErrorDiagnosticMessage::CanOnlyExtendBaseClass {
                identifier,
                declaration_range,
            } => {
                let mut message = Markup::new();
                write!(message, "Can not extend ")?;
                write!(message.code(), "{}", identifier.as_str())?;
                write!(message, " because it is not a base class.")?;
                let mut related_information = Vec::new();
                {
                    let mut message = Markup::new();
                    write!(message.code(), "{}", identifier.as_str())?;
                    related_information.push(DiagnosticRelatedInformation {
                        range: *declaration_range,
                        message: message,
                    });
                }
                Ok((message, related_information))
            }

            // Add a special case for `FunctionReturnAnnotation(None)` since the error message which
            // is generated by default isn’t great.
            ErrorDiagnosticMessage::IncompatibleTypes {
                operation: OperationSnippet::FunctionReturnAnnotation(None),
                range1: _,
                snippet1: TypeKindSnippet::Void,
                range2,
                snippet2,
            } => {
                let mut message = Markup::new();
                write!(message, "We need ")?;
                snippet2.print(&mut message, true)?;
                write!(message, " to be returned from this function.")?;
                let mut related_information = Vec::new();
                if !self.range.intersects(*range2) {
                    let mut message = Markup::new();
                    snippet2.print(&mut message, false)?;
                    related_information.push(DiagnosticRelatedInformation {
                        range: *range2,
                        message,
                    });
                }
                Ok((message, related_information))
            }

            // A Brite programmer will see this error message quite frequently so we need to take
            // some time and make sure it’s real good.
            //
            // We get an incompatible types error message when during type checking we find two
            // types that are incompatible. We will add those two types in an error message in
            // addition to the operation that failed.
            //
            // We start our error message by referencing the operation. “Cannot call”, “Cannot
            // assign”, etc. This allows us to tie our incompatibility _to an actual place in the
            // programmer’s code_. We don’t just say “these two types are incompatible”, we say “you
            // can’t do this _because_ you didn’t provide the right types”.
            //
            // We then tell the programmer the type we found and _then_ the type we expected. This
            // order was carefully thought of. The expected type is pretty static. It doesn’t change
            // much over time. However, the programmer is constantly changing which values should
            // flow into the expected type. Even if, say, the programmer changes the type of a
            // function parameter (an example of an expected type) they will then go to _all_ the
            // code sites where that function was called and update the values being passed.
            //
            // We use the related information to tell the user the exact location of the expected
            // type. We also show them the exact location of the actual type, but only if our
            // diagnostic wasn’t already pointing to the actual type. If our diagnostic is pointing
            // to the actual type we reduce clutter by not including the extra information.
            ErrorDiagnosticMessage::IncompatibleTypes {
                operation,
                range1,
                snippet1,
                range2,
                snippet2,
            } => {
                let mut message = Markup::new();
                operation.print(&mut message)?;
                write!(message, " because ")?;
                snippet1.print(&mut message, true)?;
                write!(message, " is not ")?;
                snippet2.print(&mut message, true)?;
                write!(message, ".")?;
                let mut related_information = Vec::new();
                if !self.range.intersects(*range1) {
                    let mut message = Markup::new();
                    snippet1.print(&mut message, false)?;
                    related_information.push(DiagnosticRelatedInformation {
                        range: *range1,
                        message,
                    });
                }
                if !self.range.intersects(*range2) {
                    let mut message = Markup::new();
                    snippet2.print(&mut message, false)?;
                    related_information.push(DiagnosticRelatedInformation {
                        range: *range2,
                        message,
                    });
                }
                Ok((message, related_information))
            }

            // We tell the programmer we can not perform their operation because we don’t have the
            // right number of arguments. In related information we then point them to the
            // function we found and the function we expect.
            //
            // - We use the word “argument” over “parameter” since “argument” is more common. We
            //   should always use “argument” over “parameter” in our error messages to
            //   be consistent.
            // - We don’t print out the two types since they would be really big. We trust the
            //   programmer to look them up in their IDE if necessary. We do point to the two
            //   functions in related information, though, so that the programmer has easy access
            //   to them.
            ErrorDiagnosticMessage::IncompatibleFunctionParameterLengths {
                operation,
                range1,
                len1,
                range2,
                len2,
            } => {
                let mut message = Markup::new();
                operation.print(&mut message)?;
                write!(message, " because we have ")?;
                argument_len(&mut message, *len1, true)?;
                if len1 < len2 {
                    write!(message, " but we need ")?;
                } else {
                    write!(message, " but we only need ")?;
                }
                argument_len(&mut message, *len2, false)?;
                write!(message, ".")?;
                let mut related_information = Vec::new();
                if !self.range.intersects(*range1) {
                    let mut message = Markup::new();
                    argument_len(&mut message, *len1, true)?;
                    related_information.push(DiagnosticRelatedInformation {
                        range: *range1,
                        message,
                    });
                }
                if !self.range.intersects(*range2) {
                    let mut message = Markup::new();
                    argument_len(&mut message, *len2, true)?;
                    related_information.push(DiagnosticRelatedInformation {
                        range: *range2,
                        message,
                    });
                }

                fn argument_len(
                    message: &mut Markup,
                    len: usize,
                    unit: bool,
                ) -> Result<(), fmt::Error> {
                    if let Some(len) = cardinal(len) {
                        write!(message, "{}", len)?;
                    } else {
                        write!(message, "{}", len)?;
                    }
                    if unit {
                        if len == 1 {
                            write!(message, " argument")?;
                        } else {
                            write!(message, " arguments")?;
                        }
                    }
                    Ok(())
                }

                Ok((message, related_information))
            }

            // We want a message here that helps the programmer know that they need to add a type
            // annotation without saying the word “annotation” since that falls in the category
            // of technical language the programmer doesn’t need to know.
            ErrorDiagnosticMessage::MissingFunctionParameterType { pattern } => {
                let mut message = Markup::new();
                write!(message, "We need a type for ")?;
                pattern.print(&mut message.code())?;
                write!(message, ".")?;
                Ok((message, Vec::new()))
            }

            // Tell the user we cannot call their type which is not a function. Also point to where
            // that type is defined.
            ErrorDiagnosticMessage::CannotCall {
                callee_range,
                callee_type,
            } => {
                let mut message = Markup::new();
                write!(message, "Cannot call ")?;
                callee_type.print(&mut message, true)?;
                write!(message, ".")?;
                let mut related_information = Vec::new();
                if !self.range.intersects(*callee_range) {
                    let mut message = Markup::new();
                    callee_type.print(&mut message, false)?;
                    related_information.push(DiagnosticRelatedInformation {
                        range: *callee_range,
                        message,
                    });
                }
                Ok((message, related_information))
            }
        }
    }
}

/// Converts a number to its cardinal string representation. We use a word for small numbers
/// and we return `None` for larger numbers.
fn cardinal(n: usize) -> Option<&'static str> {
    match n {
        0 => Some("zero"),
        1 => Some("one"),
        2 => Some("two"),
        3 => Some("three"),
        4 => Some("four"),
        5 => Some("five"),
        6 => Some("six"),
        7 => Some("seven"),
        8 => Some("eight"),
        9 => Some("nine"),
        10 => Some("ten"),
        11 => Some("eleven"),
        12 => Some("twelve"),
        13 => Some("thirteen"),
        14 => Some("fourteen"),
        15 => Some("fifteen"),
        16 => Some("sixteen"),
        17 => Some("seventeen"),
        18 => Some("eighteen"),
        19 => Some("nineteen"),
        20 => Some("twenty"),
        _ => None,
    }
}

impl UnexpectedSyntax {
    fn print(&self, message: &mut Markup) -> Result<(), fmt::Error> {
        match self {
            UnexpectedSyntax::Glyph(glyph) => write!(message.code(), "{}", glyph.as_str()),
            UnexpectedSyntax::Identifier => write!(message, "a variable name"),
            UnexpectedSyntax::Number => write!(message, "a number"),
            UnexpectedSyntax::Char(c) => match c {
                '\n' => write!(message.code(), "\\n"),
                '\r' => write!(message.code(), "\\r"),
                '\t' => write!(message.code(), "\\t"),
                _ => write!(message.code(), "{}", c),
            },
        }
    }
}

impl ExpectedSyntax {
    fn print(&self, message: &mut Markup) -> Result<(), fmt::Error> {
        match self {
            ExpectedSyntax::Glyph(glyph) => write!(message.code(), "{}", glyph.as_str()),
            ExpectedSyntax::Identifier => write!(message, "a name"),
            ExpectedSyntax::IdentifierKeyword(keyword) => {
                write!(message.code(), "{}", keyword.as_str())
            }
            ExpectedSyntax::BlockCommentEnd => write!(message.code(), "*/"),

            // If the user types `0b` or `0x` then, presumably, they know what they are doing and
            // want a binary or hexadecimal number. So using phrasing like “hexadecimal digit” will
            // confuse them. If a beginner stumbles upon the error message accidentally they have
            // something clear to search for.
            //
            // Otherwise, if the user types an incorrect number like `0px` we will say that we
            // expect a _number_ instead of expected a “digit” because “number” is
            // simpler vocabulary.
            ExpectedSyntax::DecimalDigit => write!(message, "a number"),
            ExpectedSyntax::BinaryDigit => write!(message, "a binary digit"),
            ExpectedSyntax::HexadecimalDigit => write!(message, "a hexadecimal digit"),

            // While a declaration or class member may be something else other than a function we
            // still say that we expected a function. Functions are the most common declaration and
            // class member. If the programmer was trying to write something other than a function
            // we don’t expect them to be confused since they know a function goes there. However,
            // a beginner might be more confused to read “class member” or “declaration”.
            ExpectedSyntax::Declaration => write!(message, "a function"),
            ExpectedSyntax::ClassMember => write!(message, "a function"),

            // NOTE: Are there more common words than “statement”, or “expression”?
            ExpectedSyntax::Statement => write!(message, "a statement"),
            ExpectedSyntax::Expression => write!(message, "an expression"),

            // The programmer should not need to be familiar with language like “pattern”. Most of
            // the time when we expect a pattern what we really want is a variable name.
            // So say that instead of “pattern”.
            ExpectedSyntax::Pattern => write!(message, "a variable name"),

            ExpectedSyntax::Type => write!(message, "a type"),
        }
    }
}

impl OperationSnippet {
    fn print(&self, message: &mut Markup) -> Result<(), fmt::Error> {
        match self {
            OperationSnippet::ExpressionAnnotation(value) => {
                write!(message, "Can not change the type of ")?;
                value.print(&mut message.code())?;
            }
            OperationSnippet::BindingStatementAnnotation(pattern, value) => {
                write!(message, "Can not set ")?;
                pattern.print(&mut message.code())?;
                write!(message, " to ")?;
                value.print(&mut message.code())?;
            }
            OperationSnippet::FunctionReturnAnnotation(statement) => {
                write!(message, "Can not return ")?;
                if let Some(statement) = statement {
                    statement.print(&mut message.code())?;
                } else {
                    // We expect all errors with this operation to be handled by our special case
                    // in `IncompatibleTypes`. So in case this expectation ever turns out to not
                    // be true panic in debug mode so we can see what broke our assumptions.
                    debug_assert!(
                        false,
                        "Should be handled by special case in `IncompatibleTypes` error message."
                    );
                    write!(message, "nothing")?;
                }
            }
            OperationSnippet::FunctionCall(callee) => {
                write!(message, "Can not call ")?;
                callee.print(&mut message.code())?;
            }
            OperationSnippet::OperatorExpression(operator) => {
                write!(message, "Can not use ")?;
                match operator {
                    OperatorSnippet::Not => write!(message.code(), "!")?,
                    OperatorSnippet::And => write!(message.code(), "&&")?,
                    OperatorSnippet::Or => write!(message.code(), "||")?,
                }
            }
        };
        Ok(())
    }
}

impl StatementSnippet {
    fn print(&self, message: &mut MarkupCode) -> Result<(), fmt::Error> {
        match self {
            StatementSnippet::Expression(expression) => expression.print(message),
            StatementSnippet::Binding(pattern, value) => {
                write!(message, "let ")?;
                pattern.print(message)?;
                write!(message, " = ")?;
                value.print(message)
            }
        }
    }
}

impl ExpressionSnippet {
    fn print(&self, message: &mut MarkupCode) -> Result<(), fmt::Error> {
        match self {
            ExpressionSnippet::Constant(constant) => write!(message, "{}", constant.print()),
            ExpressionSnippet::Reference(identifier) => write!(message, "{}", identifier.as_str()),
            ExpressionSnippet::Function(parameters) => {
                write!(message, "fun(")?;
                match parameters {
                    VecSnippet::Vec0 => {}
                    VecSnippet::Vec1(item) => item.print(message)?,
                    VecSnippet::Vec2(item1, item2) => {
                        item1.print(message)?;
                        write!(message, ", ")?;
                        item2.print(message)?;
                    }
                    VecSnippet::VecN(item1, item2) => {
                        item1.print(message)?;
                        write!(message, ", ")?;
                        item2.print(message)?;
                        write!(message, ", ...")?;
                    }
                }
                write!(message, ") {{ ... }}")
            }
            ExpressionSnippet::Call(callee) => {
                callee.print(message)?;
                write!(message, "()")
            }
            ExpressionSnippet::Prefix(operator, operand) => {
                match operator {
                    PrefixOperator::Not => write!(message, "!")?,
                    PrefixOperator::Negative => write!(message, "-")?,
                    PrefixOperator::Positive => write!(message, "+")?,
                }
                operand.print(message)
            }
            ExpressionSnippet::Logical(left, operator, right) => {
                left.print(message)?;
                match operator {
                    LogicalOperator::And => write!(message, " && ")?,
                    LogicalOperator::Or => write!(message, " || ")?,
                }
                right.print(message)
            }
            ExpressionSnippet::Block => write!(message, "do {{ ... }}"),
        }
    }
}

impl PatternSnippet {
    fn print(&self, message: &mut MarkupCode) -> Result<(), fmt::Error> {
        match self {
            PatternSnippet::Binding(identifier) => write!(message, "{}", identifier.as_str()),
        }
    }
}

impl TypeKindSnippet {
    /// The variable name `article` comes from the [grammatical element][1] of the same name.
    ///
    /// [1]: https://en.wikipedia.org/wiki/Article_(grammar)
    fn print(&self, message: &mut Markup, article: bool) -> Result<(), fmt::Error> {
        match self {
            TypeKindSnippet::Never => write!(message.code(), "Never"),
            TypeKindSnippet::Void => write!(message.code(), "Void"),
            TypeKindSnippet::Boolean => {
                if article {
                    write!(message, "a ")?;
                }
                write!(message.code(), "Bool")
            }
            TypeKindSnippet::Number => {
                if article {
                    write!(message, "a ")?;
                }
                write!(message.code(), "Num")
            }
            TypeKindSnippet::Integer => {
                if article {
                    write!(message, "an ")?;
                }
                write!(message.code(), "Int")
            }
            TypeKindSnippet::Float => {
                if article {
                    write!(message, "a ")?
                }
                write!(message.code(), "Float")
            }
            TypeKindSnippet::Function => {
                if article {
                    write!(message, "a ")?
                }
                write!(message, "function")
            }
        }
    }
}

/// A reference to a diagnostic. Can only be created by calling `DiagnosticsCollection::report()` so
/// it forces the programmer to report a diagnostic before being able to use a `DiagnosticRef`.
#[derive(Clone, Debug)]
pub struct DiagnosticRef(Rc<Diagnostic>);

impl Deref for DiagnosticRef {
    type Target = Diagnostic;

    fn deref(&self) -> &Self::Target {
        &self.0
    }
}

/// A collection of diagnostics.
pub struct DiagnosticsCollection {
    diagnostics: Vec<Rc<Diagnostic>>,
}

impl DiagnosticsCollection {
    /// Creates a new diagnostic collection.
    pub fn new() -> Self {
        DiagnosticsCollection {
            diagnostics: Vec::new(),
        }
    }

    /// Reports a diagnostic in our diagnostic collection.
    pub fn report(&mut self, diagnostic: Diagnostic) -> DiagnosticRef {
        let diagnostic = Rc::new(diagnostic);
        self.diagnostics.push(Rc::clone(&diagnostic));
        DiagnosticRef(diagnostic)
    }

    /// Is this diagnostic collection empty?
    pub fn is_empty(&self) -> bool {
        self.diagnostics.is_empty()
    }

    /// Prints our diagnostic collection to a markdown list for debugging purposes.
    pub fn markdown_list(&self, document: &Document) -> String {
        let mut output = String::new();
        for diagnostic in &self.diagnostics {
            let (message, related_information) = diagnostic.message();
            output.push_str(&format!(
                "- ({}) {}\n",
                diagnostic.range.display(document),
                message.to_simple_string()
            ));
            for info in related_information {
                output.push_str(&format!(
                    "  - ({}) {}\n",
                    info.range.display(document),
                    info.message.to_simple_string()
                ));
            }
        }
        output
    }
}
