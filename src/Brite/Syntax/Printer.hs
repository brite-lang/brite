-- Responsible for pretty printing Brite programs from a tree structure back into text. This
-- printer will not print the _exact_ source text that constructed the trees, but rather a pretty
-- version. As a community, we expect all valid Brite programs to be formatted using this printer.

{-# LANGUAGE OverloadedStrings #-}

module Brite.Syntax.Printer
  ( printModule
  ) where

import Brite.Syntax.CST
import Brite.Syntax.PrinterFramework
import Brite.Syntax.Tokens
import Data.Functor.Identity
import qualified Data.Text.Lazy.Builder as B

-- Pretty prints a Brite module.
printModule :: Module -> B.Builder
printModule = printDocument maxWidth . module_

-- We pick 80 characters as our max width. That width will fit almost anywhere: Split pane IDEs,
-- GitHub, Terminals. It is also the best for plain text comments.
--
-- * Plain text (like comments) is best at 80 characters for readability.
-- * 88 characters is the most that will fit in a GitHub PR or issue comment.
-- * 125 characters is the most that will fit in a GitHub file view.
-- * The default max width for Prettier is 80 with 2 spaces of indentation. This can be a bit tight
--   on large screens with only one code window.
-- * The default max width for Rust is 100 with 4 spaces of indentation. This will fit less
--   horizontally then Prettier. Especially considering that all code must be inside a declaration.
--   Often times multiple declarations like `fn`s in `impl`s.
maxWidth :: Int
maxWidth = 80

-- Pretty prints a Brite module.
module_ :: Module -> Document
module_ (Module ss t) =
  mconcat (map (recover statement) ss)

-- Pretty prints a recovered value.
recover :: (a -> Document) -> Recover a -> Document
recover f = runIdentity . recoverM (Identity . f)

-- Pretty prints a recovered value when the provided function returns a functor.
recoverM :: Functor f => (a -> f Document) -> Recover a -> f Document
recoverM f (Ok a) = f a

-- Pretty prints a name.
name :: Name -> Document
name = token . nameToken

----------------------------------------------------------------------------------------------------
-- # Comment Aesthetics
--
-- We need to answer the question: How are we going to pretty print comments? A programmer may put
-- a comment anywhere in their source code which might seriously disrupt the printer. First, to
-- understand what a “pretty” print involving comments might look like, let’s consider the aesthetic
-- of comments.
--
-- ## Line Comment Aesthetic
--
-- Line comments are used in Brite to document code. Programs are read left-to-right (sorry rtl
-- readers...) so the only thing which will end a line comment is a new line. No code may come after
-- a line comment on the same line. This makes the printing of line comments extra challenging.
--
-- The aesthetic for line comments we will say is “fluid decoration”. Line comments should not
-- impede the pretty printing of your code. They should not make your code less aesthetically
-- pleasing. After all, they are decorations. We are also free to move line comments around as we
-- please since part of their aesthetic is “fluid”. Just not too far from the author’s
-- original location.
--
-- There are two states a line comment might be in:
--
-- 1. Preceded by code: `a // ...`
-- 2. Not preceded by code: `// ...`
--
-- This makes the printing rules rather straightforward:
--
-- * A line comment that is preceded by code will stay on the same line as that code, but will be
--   printed at the end of the line the code was formatted onto. So if we have `a // ...` and `b`
--   and the printer chooses to put `a` and `b` on the same line the comment will move to the end of
--   the line like so `a b // ...`. This also means that if `b` has a line comment then both line
--   comments will be moved to the end of the line like so `a b // ... // ...`.
-- * A line comment that is not preceded by code will stay that way with at most one empty line
--   between the comment and whatever is next.
--
-- A line comment that is not preceded by code will break the group it was placed in. Simply because
-- it must considering we can’t put code after a line comment on the same line.
--
-- ## Block Comment Aesthetic
--
-- Block comments are included in Brite almost only to quickly hide some code. The programmer merely
-- needs to add `/*` at the start and `*/` at the end of the code they want to go bye-bye. Block
-- comments are not used for documentation as they are more difficult to type.
--
-- As such, the aesthetic for block comments can most succinctly be described as “quick and dirty”.
-- A block comment is used by a programmer who needs a quick and dirty comment.
--
-- There are four states a block comment might be in:
--
-- 1. Surrounded by code on both sides: `a /* */ b` (this comment is considered “attached”)
-- 2. Surrounded by code on the left: `a /* */` (this comment is considered “attached”)
-- 3. Surrounded by code on the right: `/* */ b` (this comment is considered “attached”)
-- 4. Surrounded by code on neither side: `/* */` (this comment is considered “detached”)
--
-- The printing rules for block comments are as follows:
--
-- * A block comment that is “attached” to a token (only spaces, not lines, between the comment and
--   the token) will be printed attached to the very same token.
-- * A block comment that is detached will continue to be detached. There may be at most one empty
--   line between the block comment and the next token.
--
-- In all these states a block comment can also contain a new line. If a block comment has a new
-- line it will automatically fail to fit its group on one line. However, the block comment will
-- stay attached.
----------------------------------------------------------------------------------------------------

-- Pretty prints a token.
token :: Token -> Document
token (Token _ k ts1 ts2) =
  leading ts1
    <> text (tokenKindSource k)
    <> trailing ts2
  where
    leading [] = mempty
    leading (Spaces _ : ts) = leading ts
    leading (Tabs _ : ts) = leading ts
    leading (Newlines _ _ : ts) = leading ts
    leading (OtherWhitespace _ : ts) = leading ts

    -- We know, for sure, that no code comes before a leading line comment. Code will eat a line
    -- comment that comes after it as trailing trivia. See the `trailing` function below. Line
    -- comments with no preceding code insert at most one empty new line.
    leading (Comment (LineComment c) : ts) =
      let (ls, ts') = newlines 0 ts in
        linePrefix (text "//" <> text c <> (if ls > 1 then hardline <> hardline else hardline))
          <> hard
          <> leading ts'

    leading (Comment (BlockComment _ _) : ts) = leading ts -- TODO

    newlines n [] = (n, [])
    newlines n (Spaces _ : ts) = newlines n ts
    newlines n (Tabs _ : ts) = newlines n ts
    newlines n (Newlines _ m : ts) = newlines (n + m) ts
    newlines n (OtherWhitespace _ : ts) = newlines n ts
    newlines n ts@(Comment _ : _) = (n, ts)

    trailing [] = mempty
    trailing (Spaces _ : ts) = trailing ts
    trailing (Tabs _ : ts) = trailing ts
    trailing (Newlines _ _ : ts) = trailing ts
    trailing (OtherWhitespace _ : ts) = trailing ts

    -- We know that some code always comes before a trailing line comment. Defer printing the
    -- comment until the printer inserts a new line. This way the printer maintains the opportunity
    -- to format code as it pleases.
    trailing (Comment (LineComment c) : ts) =
      lineSuffix (text " //" <> text c) <> trailing ts

    trailing (Comment (BlockComment _ _) : ts) = trailing ts -- TODO

-- Pretty prints a statement. Always inserts a semicolon after every statement.
statement :: Statement -> Document
statement (ExpressionStatement e t) =
  neverWrap (expression e) <> maybe (text ";") (recover token) t <> hardline
statement (BindingStatement t1 p Nothing t2 e t3) =
  token t1
    <> text " "
    <> recover pattern p
    <> text " "
    <> recover token t2
    <> text " "
    <> neverWrap (recoverM expression e)
    <> maybe (text ";") (recover token) t3
    <> hardline

-- Pretty prints a constant.
constant :: Constant -> Document
constant (BooleanConstant _ t) = token t

-- The precedence level of an expression.
data Precedence
  = Primary
  | Unary
  | Exponentiation
  | Multiplicative
  | Additive
  | Relational
  | Equality
  | LogicalAnd
  | LogicalOr
  deriving (Eq, Ord)

-- Small tuple shortcut.
pair :: a -> b -> (a, b)
pair = (,)
{-# INLINE pair #-}

-- Never wrap the expression in parentheses.
neverWrap :: (Precedence, Document) -> Document
neverWrap (_, e) = e

-- Wrap expressions at a precedence level higher than the one provided.
wrap :: Precedence -> (Precedence, Document) -> Document
wrap p1 (p2, e) | p2 > p1 = text "(" <> e <> text ")"
wrap _ (_, e) = e

-- Pretty prints an expression.
expression :: Expression -> (Precedence, Document)
expression (ConstantExpression c) = pair Primary $ constant c
expression (VariableExpression n) = pair Primary $ name n

-- Unary expressions are printed as expected.
expression (UnaryExpression _ t e) = pair Unary $
  token t <> wrap Unary (recoverM expression e)

-- Binary expressions of the same precedence level are placed in a single group.
expression (BinaryExpression l (Ok (BinaryExpressionExtra op t r))) = pair precedence $ group $
  wrapOperand (recoverM expression l)
    <> text " "
    <> token t
    <> line
    <> wrapOperand (recoverM expression r)
  where
    -- If our operand is at a greater precedence then we need to wrap it up.
    wrapOperand (p, e) | p > precedence = text "(" <> e <> text ")"
    -- If our operand is at a lesser precedence then we want to leave it grouped.
    wrapOperand (p, e) | p < precedence = e
    -- If our operand is at the same precedence then we want to inline it into our group. Only other
    -- binary expressions should be at the same precedence.
    wrapOperand (_, e) = shamefullyUngroup e

    precedence = case op of
      Add -> Additive
      Subtract -> Additive
      Multiply -> Multiplicative
      Divide -> Multiplicative
      Remainder -> Multiplicative
      Exponent -> Exponentiation
      Equals -> Equality
      NotEquals -> Equality
      LessThan -> Relational
      LessThanOrEqual -> Relational
      GreaterThan -> Relational
      GreaterThanOrEqual -> Relational
      And -> LogicalAnd
      Or -> LogicalOr

-- Always remove unnecessary parentheses.
expression (WrappedExpression _ e Nothing _) =
  recoverM expression e

-- Group a property expression and indent its property on a newline if the group breaks.
expression (ExpressionExtra e (Ok (PropertyExpressionExtra t n))) = pair Primary $ group $
  wrap Primary (expression e) <> indent (softline <> token t <> recover name n)

-- TODO: Finish call expressions
expression (ExpressionExtra e (Ok (CallExpressionExtra t1 (CommaList [] (Just (Ok arg))) t2))) = pair Primary $
  wrap Primary (expression e) <> group
    (token t1 <> indent (softline <> neverWrap (expression arg)) <> softline <> recover token t2)

-- Pretty prints a pattern.
pattern :: Pattern -> Document
pattern (VariablePattern n) = name n
