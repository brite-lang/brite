-- Welcome to the home of Brite Lite! Lite is a syntax inspired by academic tradition which freely
-- includes Unicode symbols that we use for testing the type checker. Specifically we use the syntax
-- of the [MLF thesis][1] and related papers.
--
-- No Brite programmer should ever end seeing Lite. It is only a useful tool for compiler hackers
-- and academics to describe the type checking properties of Brite. Lite directly parses an AST
-- avoiding the need to go through the CST.
--
-- There may be features in Brite that we don’t support in Lite.
--
-- And yes, we use Parsec, even though we have our own industrial grade parser which supports error
-- recovery in `Brite.Syntax.ParserFramework`. We don’t care about error recovery for this parser
-- since a Brite programmer will never right in Lite.
--
-- The biggest reason for having Lite and for writing our tests in Lite is so that, culturally, we
-- can keep Brite’s type system rooted in academics. I (Caleb) don’t have time to prove soundness of
-- a type system, but I can implement a type system that someone else has provided soundness for.
-- By having Lite we can separate Brite’s type system from the end language product we want
-- to build.
--
-- Also, especially in the early days, Brite’s syntax might change. We don’t precisely know the best
-- way to represent universal vs. existential quantification, or rigid vs. flexible bounds. Even
-- though they exist in the type system in theory. We also might use some degree of syntactic
-- punning so that multiple concepts look similar but in fact have different behaviors. Because of
-- this, it’s nice to have a stable syntax we can use to explore the type system while the real
-- Brite syntax is rooted in programming language culture.
--
-- [1]: https://pastel.archives-ouvertes.fr/file/index/docid/47191/filename/tel-00007132.pdf

{-# LANGUAGE OverloadedStrings #-}

module Brite.Semantics.Lite
  ( expressionParsec
  , typeParsec
  ) where

import Brite.Semantics.AST
import Brite.Syntax.Tokens (Position(..), unsafeIdentifier)
import Data.Functor.Identity
import qualified Data.Text as Text
import Text.Parsec hiding (Parsec)
import Text.Parsec.Language (emptyDef)
import qualified Text.Parsec.Token as P

type Parsec a = ParsecT String () Identity a

expressionParsec :: Parsec Expression
expressionParsec = expression

typeParsec :: Parsec Type
typeParsec = type'

range :: Parsec a -> Parsec (Range, a)
range p = build <$> getPosition <*> p <*> getPosition
  where
    build start a end =
      ( Range
          (Position (sourceLine start - 1) (sourceColumn start - 1))
          (Position (sourceLine end - 1) (sourceColumn end - 1))
      , a
      )

name :: Parsec Name
name = uncurry Name <$> range identifier

block :: Parsec Block
block = build <$> expression
  where
    build x = case expressionNode x of
      BlockExpression b -> b
      _ -> Block [Statement (expressionRange x) (ExpressionStatement x)]

constant :: Parsec Constant
constant =
  (pure (BooleanConstant True) <* reserved "true") <|>
  (pure (BooleanConstant False) <* reserved "false")

expression :: Parsec Expression
expression =
  unwrappedExpression
    <|> bindingExpression
    <|> functionExpression
    <|> conditionalExpression

unwrappedExpression :: Parsec Expression
unwrappedExpression = fmap (uncurry Expression) . range $
  (VariableExpression <$> identifier)
    <|> (ConstantExpression <$> constant)
    <|> (parens (WrappedExpression <$> expression <*> pure Nothing))

functionExpression :: Parsec Expression
functionExpression = fmap (uncurry Expression) . range $ fmap FunctionExpression $
  Function []
    <$> (reservedOp "λ" *> (flip (:) [] <$> functionParameter))
    <*> pure Nothing
    <*> (dot *> block)
  where
    functionParameter = FunctionParameter <$> pattern <*> pure Nothing

bindingExpression :: Parsec Expression
bindingExpression = fmap (uncurry Expression) . range $
  build <$>
    range
      ((,) <$>
        (reserved "let" *> pattern) <*>
        (reservedOp "=" *> expression <* reserved "in")) <*>
    expression
  where
    build (r, (binding, value)) body =
      let s = Statement r (BindingStatement binding Nothing value) in
        BlockExpression $ Block $ s : case expressionNode body of
          BlockExpression (Block ss) -> ss
          _ -> [Statement (expressionRange body) (ExpressionStatement body)]

conditionalExpression :: Parsec Expression
conditionalExpression =
  uncurry Expression <$> (range (ConditionalExpression <$> consequent))
  where
    consequent =
      ConditionalExpressionIf <$>
        (reserved "if" *> expression) <*>
        (reserved "then" *> block) <*>
        ((Just <$> alternate) <|> pure Nothing)

    alternate =
      reserved "else" *>
        (ConditionalExpressionElseIf <$> (reserved "if" *> consequent) <|>
         ConditionalExpressionElse <$> block)

pattern :: Parsec Pattern
pattern = fmap (uncurry Pattern) . range $
  (VariablePattern <$> identifier)

type' :: Parsec Type
type' = functionType <|> quantifiedType

unwrappedType :: Parsec Type
unwrappedType = fmap (uncurry Type) . range $
  (VariableType <$> identifier)
    <|> (reserved "bool" *> pure (VariableType (unsafeIdentifier "Bool")))
    <|> (reserved "int" *> pure (VariableType (unsafeIdentifier "Int")))
    <|> (parens (WrappedType <$> type'))
    <|> (reservedOp "⊥" *> pure BottomType)

functionType :: Parsec Type
functionType = fmap build . range $
  flip ($) <$> unwrappedType <*> option Left ((\b a -> Right (a, b)) <$> (reservedOp "→" *> functionType))
  where
    build (_, Left t) = t
    build (r, Right (a, b)) = Type r (FunctionType [] [a] b)

quantifiedType :: Parsec Type
quantifiedType = fmap (uncurry Type) . range $
  QuantifiedType <$> (reserved "∀" *> quantifiers <* dot) <*> type'
  where
    quantifiers =
      (parens (commaSep1 (Quantifier <$> name <*> optionMaybe bound)))
        <|> (flip (:) [] . flip Quantifier Nothing <$> name)

    bound = (,) <$> ((reservedOp "≥" *> pure Flexible) <|> (reservedOp "=" *> pure Rigid)) <*> type'

lexer :: P.TokenParser ()
lexer = P.makeTokenParser $ emptyDef
  { P.commentStart = "/*"
  , P.commentEnd = "*/"
  , P.commentLine = "//"
  , P.reservedNames = ["true", "false", "if", "then", "else", "let", "in", "bool", "int"]
  , P.opStart = P.opLetter emptyDef
  , P.opLetter = oneOf "λ=∀≥⊥→"
  , P.reservedOpNames = ["λ", "=", "∀", "≥", "⊥", "→"]
  }

reserved :: String -> Parsec ()
reserved = P.reserved lexer

reservedOp :: String -> Parsec ()
reservedOp = P.reservedOp lexer

identifier :: Parsec Identifier
identifier = unsafeIdentifier . Text.pack <$> P.identifier lexer

parens :: Parsec a -> Parsec a
parens = P.parens lexer

dot :: Parsec String
dot = P.dot lexer

commaSep1 :: Parsec a -> Parsec [a]
commaSep1 = P.commaSep1 lexer
