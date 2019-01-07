-- The Abstract Syntax Tree (AST) is a rather simple transformation of the Concrete Syntax Tree
-- (CST). The AST removes all the pedantic parts of the CST leaving in all the semantically relevant
-- parts. For instance, the AST removes all comments and `Recover` errors opting to express syntax
-- errors as `ErrorExpression` wrappers.

module Brite.Semantics.AST
  ( Position(..)
  , Range(..)
  , Identifier
  , Name(..)
  , Statement(..)
  , StatementNode(..)
  , Declaration(..)
  , Function(..)
  , FunctionParameter(..)
  , Block(..)
  , Constant(..)
  , Expression(..)
  , ExpressionNode(..)
  , ObjectExpressionProperty(..)
  , UnaryOperator(..)
  , BinaryOperator(..)
  , LogicalOperator(..)
  , ConditionalExpressionIf(..)
  , ConditionalExpressionElse(..)
  , Pattern(..)
  , PatternNode(..)
  , ObjectPatternProperty(..)
  , Type(..)
  , TypeNode(..)
  , ObjectTypeProperty(..)
  , Quantifier(..)
  , QuantifierBoundKind(..)
  ) where

import Brite.Diagnostics
import Brite.Syntax.CST (UnaryOperator(..), QuantifierBoundKind(..))
import qualified Brite.Syntax.CST as CST
import Brite.Syntax.Tokens (Position(..), Range(..), Identifier)

data Name = Name
  -- The range covered by a name in a document.
  { nameRange :: Range
  -- The identifier which creates the name.
  , nameIdentifier :: Identifier
  }

-- While `Statement` currently does not have any common data like `Expression` or `Pattern`, we
-- still use a `newtype` wrapper for consistency. Eventually if we add common data we won’t need a
-- large refactor.
newtype Statement = Statement
  -- The representation of a statement.
  { statementNode :: StatementNode
  }

data StatementNode
  -- `E;`
  = ExpressionStatement Expression

  -- `let P = E;`
  | BindingStatement Pattern (Maybe Type) Expression

  -- `return E;`
  | ReturnStatement (Maybe Expression)

  -- `break;`
  | BreakStatement (Maybe Expression)

  -- Some declaration which is not order dependent unlike all statements.
  | Declaration Declaration

  -- Marks the position of some error in the AST. We may or may not have been able to recover from
  -- the error. If we recovered then the AST node will be `Just` otherwise it will be `Nothing`.
  --
  -- We will panic at runtime if someone attempts to execute this node.
  | ErrorStatement Diagnostic (Maybe Statement)

-- NOTE: Eventually we will also add a `TypeDeclaration`.
data Declaration
  -- `fun f() {}`
  --
  -- If we failed to parse a name for the function then the name will be `Left` instead of `Right`.
  -- We do this so we don’t have to throw away our entire function declaration just because of a
  -- missing name.
  = FunctionDeclaration (Either Diagnostic Name) Function

-- `fun() {}`
data Function = Function
  { functionQuantifiers :: [Quantifier]
  , functionParameters :: [FunctionParameter]
  , functionReturn :: Maybe Type
  , functionBody :: Block
  }

-- `P: T`
data FunctionParameter = FunctionParameter Pattern (Maybe Type)

-- `{ ... }`
newtype Block = Block
  { blockStatements :: [Statement]
  }

data Constant
  -- `true`, `false`
  = BooleanConstant Bool

data Expression = Expression
  -- The range covered by an expression in a document.
  { expressionRange :: Range
  -- The representation of an expression.
  , expressionNode :: ExpressionNode
  }

data ExpressionNode
  -- `C`
  = ConstantExpression Constant

  -- `x`
  | VariableExpression Identifier

  -- `fun() {}`
  | FunctionExpression Function

  -- `{p: E}`
  | ObjectExpression [ObjectExpressionProperty] (Maybe Expression)

  -- TODO: | VariantExpression

  -- `-E`
  | UnaryExpression UnaryOperator Expression

  -- `E + E`
  --
  -- Logical operators like `&&` and `||` are moved to the `LogicalExpression` variant.
  | BinaryExpression Expression BinaryOperator Expression

  -- `E && E`
  --
  -- We have different variants for `BinaryExpression` and `LogicalExpression` in our AST because
  -- when a logical expression executes we might not evaluate the second expression. This is called
  -- “short-circuiting”. For instance, `false && E` will not evaluate `E` since we know that the
  -- only solution is `false`.
  | LogicalExpression Expression LogicalOperator Expression

  -- `if E {} else {}`
  | ConditionalExpression ConditionalExpressionIf

  -- TODO: | MatchExpression

  -- `do {}`
  | BlockExpression Block

  -- `loop {}`
  | LoopExpression Block

  -- `(E)`, `(E: T)`
  | WrappedExpression Expression (Maybe Type)

  -- `E.p`
  | PropertyExpression Expression Name

  -- `f(E)`
  | CallExpression Expression [Expression]

  -- Marks the position of some error in the AST. We may or may not have been able to recover from
  -- the error. If we recovered then the AST node will be `Just` otherwise it will be `Nothing`.
  --
  -- We will panic at runtime if someone attempts to execute this node.
  | ErrorExpression Diagnostic (Maybe Expression)

-- `p: E`
data ObjectExpressionProperty = ObjectExpressionProperty Name (Maybe Expression)

data BinaryOperator
  -- `+`
  = Add
  -- `-`
  | Subtract
  -- `*`
  | Multiply
  -- `/`
  | Divide
  -- `%`
  | Remainder
  -- `^`
  | Exponent
  -- `==`
  | Equals
  -- `!=`
  | NotEquals
  -- `<`
  | LessThan
  -- `<=`
  | LessThanOrEqual
  -- `>`
  | GreaterThan
  -- `>=`
  | GreaterThanOrEqual

data LogicalOperator
  -- `&&`
  = And
  -- `||`
  | Or

-- `if E { ... }`
data ConditionalExpressionIf =
  ConditionalExpressionIf Expression Block (Maybe ConditionalExpressionElse)

data ConditionalExpressionElse
  -- `else { ... }`
  = ConditionalExpressionElse Block
  -- `else if E { ... }`
  | ConditionalExpressionElseIf ConditionalExpressionIf

data Pattern = Pattern
  -- The range covered by a pattern in a document.
  { patternRange :: Range
  -- The representation of a pattern.
  , patternNode :: PatternNode
  }

data PatternNode
  -- `C`
  = ConstantPattern Constant

  -- `x`
  | VariablePattern Identifier

  -- `_`
  | HolePattern

  -- `{p: P}`
  | ObjectPattern [ObjectPatternProperty] (Maybe Pattern)

  -- TODO: | VariantPattern

  -- `(P)`
  | WrappedPattern Pattern

  -- Marks the position of some error in the AST. We may or may not have been able to recover from
  -- the error. If we recovered then the AST node will be `Just` otherwise it will be `Nothing`.
  --
  -- We will panic at runtime if someone attempts to execute this node.
  | ErrorPattern Diagnostic (Maybe Pattern)

-- `p: P`
data ObjectPatternProperty = ObjectPatternProperty Name (Maybe Pattern)

data Type = Type
  -- The range covered by the type in a document.
  { typeRange :: Range
  -- The representation of a type.
  , typeNode :: TypeNode
  }

data TypeNode
  -- `x`
  = VariableType Identifier

  -- `!`
  | BottomType

  -- `fun() -> T`
  --
  -- NOTE: We can parse quantifiers within a function type `fun<T>(T) -> T` but in our AST we
  -- represent this as a quantified type wrapping a function type.
  | FunctionType [Type] Type

  -- `{p: T}`
  | ObjectType [ObjectTypeProperty] (Maybe Type)

  -- TODO: | VariantType

  -- `<x> T`
  | QuantifiedType [Quantifier] Type

  -- `(T)`
  | WrappedType Type

  -- Marks the position of some error in the AST. We may or may not have been able to recover from
  -- the error. If we recovered then the AST node will be `Just` otherwise it will be `Nothing`.
  --
  -- We will panic at runtime if someone attempts to execute this node.
  | ErrorType Diagnostic (Maybe Type)

-- `p: T`
data ObjectTypeProperty = ObjectTypeProperty Name (Maybe Type)

-- `x: T`
data Quantifier = Quantifier Name (Maybe (QuantifierBoundKind, Type))

-- A monad for converting CST nodes to AST nodes in the same form as the CST `Recover` data type. If
-- we recover multiple times then we will use the first error.
data Recover a
  = Ok a
  | Recover Diagnostic a
  | Fatal Diagnostic

instance Functor Recover where
  fmap f (Ok a) = Ok (f a)
  fmap f (Recover e a) = Recover e (f a)
  fmap _ (Fatal e) = Fatal e

instance Applicative Recover where
  pure a = Ok a

  Fatal e <*> _ = Fatal e
  _ <*> Fatal e = Fatal e
  Recover e f <*> Recover _ a = Recover e (f a)
  Recover e f <*> Ok a = Recover e (f a)
  Ok f <*> Recover e a = Recover e (f a)
  Ok f <*> Ok a = Ok (f a)

instance Monad Recover where
  Ok a >>= f = f a
  Fatal e >>= _ = Fatal e
  Recover e a >>= f =
    case f a of
      Fatal e2 -> Fatal e2
      Recover _ b -> Recover e b
      Ok b -> Recover e b

-- Converts a CST `Recover` into an AST `Recover`.
recover :: CST.Recover a -> Recover a
recover (CST.Fatal _ e) = Fatal e
recover (CST.Recover _ e a) = Recover e a
recover (CST.Ok a) = Ok a

-- Runs the `Recover` monad and takes an error constructor for the node. The error constructor is
-- called if there is a fatal error or an error recovery.
runRecover :: (Diagnostic -> Maybe a -> a) -> Recover a -> a
runRecover f (Fatal e) = f e Nothing
runRecover f (Recover e a) = f e (Just a)
runRecover _ (Ok a) = a

-- -- Converts a CST expression into an AST expression.
-- expressionFromCST :: CST.Expression -> Expression
-- expressionFromCST x0 = runRecover build $ case x0 of
--   CST.ConstantExpression (CST.BooleanConstant b t) ->
--     return (Expression (tokenRange t) (ConstantExpression (BooleanConstant b)))
