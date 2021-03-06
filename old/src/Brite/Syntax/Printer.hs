-- Responsible for pretty printing Brite programs from a tree structure back into text. This
-- printer will not print the _exact_ source text that constructed the trees, but rather a pretty
-- version. As a community, we expect all valid Brite programs to be formatted using this printer.
--
-- Unlike other components of Brite, the printer is “best effort” based on heuristics we choose as a
-- community. It isn’t “this must be correct at all costs” like the type system. If there is even a
-- small edge case implemented incorrectly in the type system it could open Brite up to security
-- bugs. It’s fine for the printer to have small edge cases with suboptimal output, though. As long
-- as these edge cases are uncommon.
--
-- NOTE: It would be a good idea to generate Brite programs and make sure that
-- `print(code) = print(print(code))`. Also that there are never any trailing spaces.

{-# LANGUAGE OverloadedStrings #-}

module Brite.Syntax.Printer
  ( printModule
  , printCompactType
  , printCompactQuantifierList
  ) where

import Brite.Syntax.CST (recoverStatementTokens)
import Brite.Syntax.Identifier
import Brite.Syntax.Number
import Brite.Syntax.PrinterAST
import Brite.Syntax.PrinterFramework
import Brite.Syntax.Token
import Data.Char (isDigit, isSpace)
import qualified Data.Text as Text
import qualified Data.Text.Lazy as Text.Lazy
import qualified Data.Text.Lazy.Builder as Text (Builder)
import qualified Data.Text.Lazy.Builder as Text.Builder

-- Pretty prints a Brite module. The module must be from the printer AST.
printModule :: Module -> Text.Builder
printModule = printDocument maxWidth . printStatementSequence . moduleStatements

-- Pretty prints a type compactly. The type must be from the printer AST.
printCompactType :: Type -> Text.Builder
printCompactType = printCompactDocument . printType

-- Prints a quantifier list compactly. The quantifier list must come from the printer AST.
printCompactQuantifierList :: [Quantifier] -> Text.Builder
printCompactQuantifierList [] = Text.Builder.fromText "<>"
printCompactQuantifierList qs =
  printCompactDocument (printQuantifierList TypeQuantifierContext (map (\x -> Right (x, [])) qs))

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

-- Adds two lists together with `++` but with a special case for an empty list on the right.
append :: [a] -> [a] -> [a]
append as [] = as
append as1 as2 = as1 ++ as2
{-# INLINE append #-}

-- Prints an unattached comment from the printer AST.
printUnattachedComment :: UnattachedComment -> Document
printUnattachedComment c0 =
  (if unattachedCommentLeadingEmptyLine c0 then hardline else mempty) <>
    (case unattachedComment c0 of
      LineComment c -> text "//" <> text (Text.dropWhileEnd isSpace c)
      BlockComment c _ ->
        text "/*"
          <> text (Text.Lazy.toStrict (Text.Builder.toLazyText (removeTrailingSpaces c)))
          <> text "*/")
    <> hardline

-- Prints a list of leading attached comments. Attached line comments will always go to the end of
-- the line.
printLeadingAttachedComments :: [AttachedComment] -> Document
printLeadingAttachedComments cs = mconcat $ flip map cs $ \c0 ->
  case attachedComment c0 of
    LineComment c -> lineSuffix (text " //" <> text (Text.dropWhileEnd isSpace c))
    BlockComment c _ ->
      text "/*"
        <> text (Text.Lazy.toStrict (Text.Builder.toLazyText (removeTrailingSpaces c)))
        <> text "*/ "

-- Prints a list of trailing attached comments. Attached line comments will always go to the
-- end of the line.
printTrailingAttachedComments :: [AttachedComment] -> Document
printTrailingAttachedComments cs = mconcat $ flip map cs $ \c0 ->
  case attachedComment c0 of
    LineComment c -> lineSuffix (text " //" <> text (Text.dropWhileEnd isSpace c))
    BlockComment c _ ->
      text " /*"
        <> text (Text.Lazy.toStrict (Text.Builder.toLazyText (removeTrailingSpaces c)))
        <> text "*/"

-- Prints a list separated by commas. If the list is broken onto multiple lines we will always add a
-- trailing comma. The function for printing an individual comma list item returns a list of
-- trailing comments before and after the comma.
printCommaList :: (a -> (Document, [AttachedComment])) -> [CommaListItem a] -> Document
printCommaList f = loopStart
  where
    loopStart (Left (UnattachedComment True c) : as) = loop (Left (UnattachedComment False c) : as)
    loopStart as = loop as

    loop [] = mempty
    loop (Left c : as) = printUnattachedComment c <> loop as
    loop [Right (a, cs2)] =
      let (b, cs1) = f a in
        b <>
        ifBreakElse
          (text "," <> printTrailingAttachedComments cs1 <> printTrailingAttachedComments cs2 <> hardline)
          (printTrailingAttachedComments cs1 <> printTrailingAttachedComments cs2)
    loop (Right (a, cs2) : as) =
      let (b, cs1) = f a in
        b <>
        ifBreakElse
          (text "," <> printTrailingAttachedComments cs1 <> printTrailingAttachedComments cs2 <> hardline)
          (printTrailingAttachedComments cs1 <> text "," <> printTrailingAttachedComments cs2 <> text " ") <>
        loop as

-- Prints a sequence of statements or comments.
printStatementSequence :: [MaybeComment Statement] -> Document
printStatementSequence ss0 = loopStart ss0
  where
    loopStart [] = mempty
    loopStart (Left (UnattachedComment True c) : ss) = loop (Left (UnattachedComment False c) : ss)
    loopStart (Right (Statement True cs1 cs2 s) : ss) = loop (Right (Statement False cs1 cs2 s) : ss)
    loopStart ss = loop ss

    loop [] = mempty
    loop (Left c : ss) = printUnattachedComment c <> loop ss
    loop (Right s : ss) = printStatement s <> loop ss

-- Prints a single statement.
printStatement :: Statement -> Document
printStatement s0 = build $ case statementNode s0 of
  -- For concrete statements we failed to convert them to the printer AST. Presumably because they
  -- contained a parse error. Print out the raw source code for concrete statements.
  ConcreteStatement s -> rawText (tokensTrimmedSource (recoverStatementTokens s))

  -- Print an expression statement and include a semicolon for the appropriate expressions. If the
  -- expression has attached trailing comments then print those _after_ the semicolon.
  ExpressionStatement x' ->
    let (x, cs) = takeExpressionTrailingComments (processExpression x') in
      printExpression Normal Top x
        <> (if withoutSemicolon (expressionNode x) then mempty else text ";")
        <> printTrailingAttachedComments cs
    where
      withoutSemicolon (ConstantExpression _) = False
      withoutSemicolon (VariableExpression _) = False
      withoutSemicolon (FunctionExpression (Function { functionName = Just _ })) = True
      withoutSemicolon (FunctionExpression _) = False
      withoutSemicolon (CallExpression _ _) = False
      withoutSemicolon (ObjectExpression _ _) = False
      withoutSemicolon (PropertyExpression _ _ _) = False
      withoutSemicolon (PrefixExpression _ _) = False
      withoutSemicolon (InfixExpression _ _ _ _) = False
      withoutSemicolon (ConditionalExpression _) = True
      withoutSemicolon (BlockExpression _) = True
      withoutSemicolon (LoopExpression _) = True
      withoutSemicolon (WrappedExpression _ _) = False

  -- Print expressions that should break on a new line and comments specifically written above
  -- the value.
  --
  -- NOTE: If the expression has trailing comments then print those _after_ the semicolon.
  BindingStatement p t cs1 x1 | not (null cs1) || shouldBreakOntoNextLine x1 ->
    let (x, cs3) = takeExpressionTrailingComments (processExpression x1) in
      -- NOTE: Adding another `group` here may break our carefully crafted
      -- `ifBreak`/`ifFlat` conditions.
      group $ text "let "
        <> printPattern p
        <> maybe mempty ((text ": " <>) . printType) t
        <> text " ="
        <> line
        <> indent
            (mconcat (map printUnattachedComment cs2)
              <> printExpression Normal Top x)
        <> text ";"
        <> printTrailingAttachedComments cs3
      where
        cs2 = case cs1 of
          UnattachedComment True c : cs -> UnattachedComment False c : cs
          _ -> cs1

  -- IMPORTANT: It is ok to ignore the comments here because the above branch will match if we have
  -- some comments.
  --
  -- NOTE: If the expression has trailing comments then print those _after_ the semicolon.
  BindingStatement p t _ x1 ->
    let (x, cs) = takeExpressionTrailingComments (processExpression x1) in
      text "let "
        <> printPattern p
        <> maybe mempty ((text ": " <>) . printType) t
        <> text " = "
        <> printExpression Normal Top x
        <> text ";"
        <> printTrailingAttachedComments cs

  -- NOTE: If the expression has trailing comments then print those _after_ the semicolon.
  ReturnStatement (Just (cs1, x1)) | not (null cs1) || shouldBreakOntoNextLine x1 ->
    let (x, cs3) = takeExpressionTrailingComments (processExpression x1) in
      -- NOTE: Adding another `group` here may break our carefully crafted
      -- `ifBreak`/`ifFlat` conditions.
      group $ text "return "
        <> ifBreak (text "(")
        <> softline
        <> indent
            (mconcat (map printUnattachedComment cs2)
              <> printExpression Normal Top x
              <> ifBreak (printTrailingAttachedComments cs3))
        <> softline
        <> ifBreak (text ")")
        <> text ";"
        <> ifFlat (printTrailingAttachedComments cs3)
    where
      cs2 = case cs1 of
        UnattachedComment True c : cs -> UnattachedComment False c : cs
        _ -> cs1

  -- IMPORTANT: It is ok to ignore the comments here because the above branch will match if we have
  -- some comments.
  --
  -- NOTE: If the expression has trailing comments then print those _after_ the semicolon.
  ReturnStatement (Just (_, x1)) ->
    let (x, cs) = takeExpressionTrailingComments (processExpression x1) in
      text "return " <> printExpression Normal Top x <> text ";" <> printTrailingAttachedComments cs

  -- NOTE: If the expression has trailing comments then print those _after_ the semicolon.
  BreakStatement (Just (cs1, x1)) | not (null cs1) || shouldBreakOntoNextLine x1 ->
    let (x, cs) = takeExpressionTrailingComments (processExpression x1) in
      -- NOTE: Adding another `group` here may break our carefully crafted
      -- `ifBreak`/`ifFlat` conditions.
      group $ text "break "
        <> ifBreak (text "(")
        <> softline
        <> indent
            (mconcat (map printUnattachedComment cs2)
              <> printExpression Normal Top x
              <> ifBreak (printTrailingAttachedComments cs))
        <> softline
        <> ifBreak (text ")")
        <> text ";"
        <> ifFlat (printTrailingAttachedComments cs)
    where
      cs2 = case cs1 of
        UnattachedComment True c : cs -> UnattachedComment False c : cs
        _ -> cs1

  -- IMPORTANT: It is ok to ignore the comments here because the above branch will match if we have
  -- some comments.
  --
  -- NOTE: If the expression has trailing comments then print those _after_ the semicolon.
  BreakStatement (Just (_, x1)) ->
    let (x, cs) = takeExpressionTrailingComments (processExpression x1) in
      text "break " <> printExpression Normal Top x <> text ";" <> printTrailingAttachedComments cs

  ReturnStatement Nothing ->
    text "return;"

  BreakStatement Nothing ->
    text "break;"

  where
    build s1 =
      (if statementLeadingEmptyLine s0 then hardline else mempty)
        <> printLeadingAttachedComments (statementLeadingComments s0)
        <> s1
        <> printTrailingAttachedComments (statementTrailingComments s0)
        <> (case statementNode s0 of { ConcreteStatement _ -> mempty; _ -> hardline })

-- Prints a block, but the block is not wrapped in a group. That means it will only be flattened if
-- a parent group is wrapped in a block.
--
-- If the block is only a single expression statement (without comments) then we attempt to print
-- that expression statement on a single line.
printUngroupedBlock :: Block -> Document
printUngroupedBlock (Block []) = text "{}"
printUngroupedBlock (Block [Right s@(Statement { statementNode = ExpressionStatement x })]) =
  text "{"
    <> indent
      (line
        <> printLeadingAttachedComments (statementLeadingComments s)
        <> printExpression Normal Top x
        <> printTrailingAttachedComments (statementTrailingComments s)
        <> line)
    <> text "}"
printUngroupedBlock (Block ss) =
  -- Statements in a statement sequence will always end with a new line.
  text "{" <> indent (line <> printStatementSequence ss) <> text "}"

-- Prints a block.
printBlock :: Block -> Document
printBlock = group . printUngroupedBlock

-- Prints a function. Either a function expression or a function declaration.
printFunction :: Function -> Document
printFunction (Function n qs ps r b) =
  text "fun" <>
  maybe mempty ((text " " <>) . text . identifierText) n <>
  printQuantifierList FunctionQuantifierContext qs <>
  group (text "(" <> indent (softline <> printCommaList printFunctionParameter ps) <> text ")") <>
  maybe mempty ((text " -> " <>) . printType) r <>
  text " " <>
  printBlock b
  where
    printFunctionParameter (FunctionParameter p' Nothing) =
      let (p, cs) = takePatternTrailingComments (processPattern p') in
        (printPattern p, cs)

    printFunctionParameter (FunctionParameter p (Just t')) =
      let (t, cs) = takeTypeTrailingComments (processType t') in
        (printPattern p <> text ": " <> printType t, cs)

-- Prints a constant.
printConstant :: Constant -> Document
printConstant constant = case constant of
  VoidConstant -> text "void"
  BooleanConstant True -> text "true"
  BooleanConstant False -> text "false"
  NumberConstant (DecimalInteger raw _) -> text raw
  NumberConstant (BinaryInteger _ raw _) -> text "0b" <> text raw

  -- Convert all the letters in a hexadecimal integer to uppercase.
  NumberConstant (HexadecimalInteger _ raw _) -> text "0x" <> text (Text.toUpper raw)

  -- We do a couple of things to pretty print a float:
  --
  -- * If a `.` is at the very beginning of the number then add a 0 to the number’s beginning.
  -- * If a `.` is not followed by a digit then we remove it.
  -- * Lowercase `E` to `e`.
  -- * Drop the `+` in `e+`.
  NumberConstant (DecimalFloat raw0 _) -> text $
    Text.unfoldr
      (\acc ->
        let
          loop (first, raw1) =
            case (first, Text.uncons raw1) of
              -- If we see a `.` at the very beginning of our number, then insert a 0.
              (True, Just ('.', _)) -> Just ('0', (False, raw1))

              -- If we see a `.` which is not immediately followed by a digit then drop the `.`.
              (_, Just ('.', raw2)) | not (not (Text.null raw2) && isDigit (Text.head raw2)) -> loop (False, raw2)

              -- Convert an uppercase `E` into a lower case `e` and if we see a `+` immediately
              -- following the `e`, remove it.
              (_, Just ('e', raw2)) | not (Text.null raw2) && Text.head raw2 == '+' -> Just ('e', (False, Text.tail raw2))
              (_, Just ('E', raw2)) | not (Text.null raw2) && Text.head raw2 == '+' -> Just ('e', (False, Text.tail raw2))
              (_, Just ('E', raw2)) -> Just ('e', (False, raw2))

              -- Add to the number like normal.
              (_, Just (c, raw2)) -> Just (c, (False, raw2))
              (_, Nothing) -> Nothing
        in
          loop acc)
      (True, raw0)

-- Prints an expression.
printExpression :: ParseBehavior -> Precedence -> Expression -> Document
printExpression behavior expectedPrecedence x0' = build $ case expressionNode x0 of
  ConstantExpression c -> printConstant c

  VariableExpression n -> text (identifierText n)

  FunctionExpression f -> printFunction f

  -- Call expressions with a single argument never add a trailing comma. This was a pet-peeve of
  -- mine (Caleb) in the JavaScript pretty printing library [Prettier][1]. One of the primary
  -- reasons for trailing commas is to improve differences in the programmer’s source control
  -- manager (like git). Adding a new line to a trailing comma list only changes one line. It does
  -- not also change the line above it by adding a comma. It is also easy to copy/paste a new item
  -- in a trailing comma list since you don’t need to worry about adding a new comma.
  --
  -- However, functions usually don’t have a variable number of arguments. Most of the time the
  -- number of function arguments never changes so the convenience of a trailing comma list is not
  -- relevant. Trailing commas in function calls with a single item do actively look worse (in my
  -- opinion), though. Especially in JavaScript when you’d have an arrow function
  -- (`(x, y) => x + y`) and you’d have to put a trailing comma after it.
  --
  -- This is my pretty printing framework now, so I get to call the shots.
  --
  -- [1]: https://prettier.io
  CallExpression x1 xs ->
    if exactly (1 :: Int) xs then
      printExpression behavior Primary x1
        <> group (text "("
            <> indent (softline <> printSingleArgStart xs)
            <> text ")")
    else
      printExpression behavior Primary x1
        <> group (text "("
            <> indent (softline <> printCommaList printArg xs)
            <> text ")")
    where
      -- Prints an expression while also removing trailing comments to let our comma list handle the
      -- trailing comments.
      printArg x' =
        let (x, cs) = takeExpressionTrailingComments (processExpression x') in
          (printExpression Normal Top x, cs)

      -- Returns true if we have exactly `n` arguments.
      exactly n [] = n == 0
      exactly n (Left _ : args) = exactly n args
      exactly n (Right _ : _) | n == 0 = False
      exactly n (Right _ : args) = exactly (n - 1) args

      -- Print an argument list when we only have a single argument. Single argument lists never
      -- print trailing comments. See our justification above.
      printSingleArgStart (Left (UnattachedComment True c) : as) =
        printSingleArg (Left (UnattachedComment False c) : as)
      printSingleArgStart as = printSingleArg as

      -- Print our single argument without a trailing comment!
      printSingleArg [] = mempty
      printSingleArg (Left c : as) = printUnattachedComment c <> printSingleArg as
      printSingleArg (Right (a, cs) : as) =
        printExpression Normal Top a <> printTrailingAttachedComments cs <> softline <> printSingleArg as

  -- NOTE: We automatically convert `{p: p}` into `{p}`.
  ObjectExpression ps ext -> group $ behaviorWrap $
    text "{" <>
    indent (softline <> printCommaList printProperty ps) <>
    printExtension ext <>
    text "}"
    where
      -- If the parsing behavior is `NoLeftBrace` then we need to wrap our object expression to
      -- avoid a parse error.
      behaviorWrap = case behavior of
        NoLeftBrace -> \x -> text "(" <> x <> text ")"
        _ -> id

      -- The trailing comments of a punned object expression are printed by `printCommaList`.
      printProperty (ObjectExpressionPropertyPun cs1 cs2 n) =
        (printLeadingAttachedComments cs1 <> text (identifierText n), cs2)

      -- If the object property is a variable expression with the same name then automatically pun
      -- the object property.
      --
      -- NOTE: This may be a bit confusing to beginners!
      printProperty (ObjectExpressionProperty cs1 n1 cs2' (Expression cs3 cs4 (VariableExpression n2))) | n1 == n2 =
        let
          -- Remove the leading empty line from our list of unattached comments.
          cs2 = case cs2' of
            UnattachedComment True c : cs -> UnattachedComment False c : cs
            cs -> cs

          -- Print the object property as a punned property.
          (property, cs5) =
            printProperty (ObjectExpressionPropertyPun (cs1 `append` cs3) cs4 n1)
        in
          (mconcat (map printUnattachedComment cs2) <> property, cs5)

      -- Print an object property as normal.
      printProperty (ObjectExpressionProperty cs1 n cs2' x') =
        let
          -- The trailing comments of our expression are printed by `printCommaList` after
          -- the comma.
          (x, cs3) = takeExpressionTrailingComments (processExpression x')
          -- Remove the leading empty line from our list of unattached comments.
          cs2 = case cs2' of
            UnattachedComment True c : cs -> UnattachedComment False c : cs
            cs -> cs
        in
          ( group $
              printLeadingAttachedComments cs1 <>
              text (identifierText n) <>
              text ":" <>
              -- If either we have some unattached comments or the expression should be broken onto
              -- a new line when printing then make sure when this property breaks we put the
              -- expression on a new line and we add indentation.
              (if not (null cs2) || shouldBreakOntoNextLine x then
                line <>
                indent (mconcat (map printUnattachedComment cs2) <> printExpression Normal Top x)
              else
                text " " <> printExpression Normal Top x)
          , cs3
          )

      printExtension Nothing = mempty
      printExtension (Just x) =
        -- If the object breaks onto multiple lines then put the bar at the same indentation level
        -- as `{}`.
        (if null ps then text "| " else ifBreakElse (text "| ") (text " | ")) <>
        indent (printExpression Normal Top x) <>
        softline

  -- Print a property statement which may have some unattached comments over the property.
  PropertyExpression e cs n ->
    printExpression behavior Primary e <> group (indent
      (softline
        <> mconcat (map printUnattachedComment cs)
        <> text "." <> text (identifierText n)))

  PrefixExpression op' x -> op <> printExpression Normal Prefix x
    where
      op = case op' of
        Not -> text "!"
        Positive -> text "+"
        Negative -> text "-"

  InfixExpression l op' cs r ->
    -- Group the infix expression if we were printed at a different precedence level than our own.
    -- This means operators of the same precedence will be put together in one group.
    (if expectedPrecedence /= actualPrecedence then group else id)
      (printExpression behavior actualPrecedence l <> text " " <> text op <>
        -- If we are wrapping this expression then when there is a new line we want to indent by a
        -- single space. That lines up our first line (which comes after a `(`) and future lines.
        (if wrap then indent1 else id)
          (line
            <> mconcat (map printUnattachedComment cs)
            <> printExpression Normal actualPrecedence r))
    where
      op = case op' of
        Add -> "+"
        Subtract -> "-"
        Multiply -> "*"
        Divide -> "/"
        Remainder -> "%"
        Exponent -> "^"
        Equals -> "=="
        NotEquals -> "!="
        LessThan -> "<"
        LessThanOrEqual -> "<="
        GreaterThan -> ">"
        GreaterThanOrEqual -> ">="
        And -> "&&"
        Or -> "||"

  ConditionalExpression c0 ->
    group (consequent c0)
    where
      consequent (ConditionalExpressionIf cs1 x b a) =
        text "if " <>
        (if not (null cs1) || shouldBreakOntoNextLine x then group $
          let
            cs2 = case cs1 of
              UnattachedComment True c : cs -> UnattachedComment False c : cs
              _ -> cs1
          in
            ifBreak (text "(") <>
            softline <>
            indent (mconcat (map printUnattachedComment cs2) <> printExpression NoLeftBrace Top x) <>
            softline <>
            ifBreak (text ")")
        else
          printExpression NoLeftBrace Top x) <>
        text " " <>
        printUngroupedBlock b <>
        maybe mempty alternate a

      alternate (ConditionalExpressionElse [] b) = text " else " <> printUngroupedBlock b
      alternate (ConditionalExpressionElse cs b) =
        hardline <> mconcat (map printUnattachedComment cs) <> text "else " <> printUngroupedBlock b

      alternate (ConditionalExpressionElseIf [] c) = text " else " <> consequent c
      alternate (ConditionalExpressionElseIf cs c) =
        hardline <> mconcat (map printUnattachedComment cs) <> text "else " <> consequent c

  BlockExpression b -> text "do " <> printBlock b
  LoopExpression b -> text "loop " <> printBlock b

  WrappedExpression x t ->
    if shouldBreakOntoNextLine x then
      text "(" <> indent1 (printExpression behavior Top x <> text ": " <> printType t) <> text ")"
    else
      text "(" <> printExpression Normal Top x <> text ": " <> printType t <> text ")"

  where
    -- Take the leading and trailing comments for our expression.
    (attachedLeadingComments, (x0, attachedTrailingComments)) =
      takeExpressionTrailingComments <$> takeExpressionLeadingComments (processExpression x0')

    -- Finishes printing an expression node by printing leading/trailing attached comments and
    -- parentheses in case we need them.
    build x1 =
      (if wrap then text "(" else mempty)
        <> printLeadingAttachedComments attachedLeadingComments
        <> x1
        <> printTrailingAttachedComments attachedTrailingComments
        <> (if wrap then text ")" else mempty)

    -- Whether or not we should wrap this expression based on its precedence level.
    wrap = expectedPrecedence < actualPrecedence

    -- Get the actual precedence of our expression. Not the expected precedence our function
    -- was provided.
    actualPrecedence = case expressionNode x0 of
      ConstantExpression _ -> Primary
      VariableExpression _ -> Primary

      -- For aesthetic reasons we always want to wrap function expressions unless they are printed
      -- at “top”. However, we parse function expressions as primary expressions. This helps make
      -- it visually obvious when a function is being used as an expression and not a declaration.
      FunctionExpression _ -> Top

      CallExpression _ _ -> Primary
      ObjectExpression _ _ -> Primary
      PropertyExpression _ _ _ -> Primary
      PrefixExpression _ _ -> Prefix
      InfixExpression _ Add _ _ -> Additive
      InfixExpression _ Subtract _ _ -> Additive
      InfixExpression _ Multiply _ _ -> Multiplicative
      InfixExpression _ Divide _ _ -> Multiplicative
      InfixExpression _ Remainder _ _ -> Multiplicative
      InfixExpression _ Exponent _ _ -> Exponentiation
      InfixExpression _ Equals _ _ -> Equality
      InfixExpression _ NotEquals _ _ -> Equality
      InfixExpression _ LessThan _ _ -> Relational
      InfixExpression _ LessThanOrEqual _ _ -> Relational
      InfixExpression _ GreaterThan _ _ -> Relational
      InfixExpression _ GreaterThanOrEqual _ _ -> Relational
      InfixExpression _ And _ _ -> LogicalAnd
      InfixExpression _ Or _ _ -> LogicalOr
      ConditionalExpression _ -> Primary
      BlockExpression _ -> Primary
      LoopExpression _ -> Primary
      WrappedExpression _ _ -> Primary

-- How the parser behaves when parsing a specific expression.
data ParseBehavior
  = Normal
  | NoLeftBrace

-- The precedence level of an expression.
data Precedence
  = Primary
  | Prefix
  | Exponentiation
  | Multiplicative
  | Additive
  | Relational
  | Equality
  | LogicalAnd
  | LogicalOr
  -- The highest level of precedence. Includes every expression. Terminology taken from set theory
  -- “top” and “bottom”.
  | Top
  deriving (Eq, Ord)

-- Prints a pattern.
printPattern :: Pattern -> Document
printPattern x0' = build $ case patternNode x0 of
  ConstantPattern c -> printConstant c

  VariablePattern n -> text (identifierText n)

  HolePattern -> text "_"

  -- NOTE: We automatically convert `{p: p}` into `{p}`.
  ObjectPattern ps ext -> group $
    text "{" <>
    indent (softline <> printCommaList printProperty ps) <>
    printExtension ext <>
    text "}"
    where
      -- The trailing comments of a punned object expression are printed by `printCommaList`.
      printProperty (ObjectPatternPropertyPun cs1 cs2 n) =
        (printLeadingAttachedComments cs1 <> text (identifierText n), cs2)

      -- If the object property is a variable expression with the same name then automatically pun
      -- the object property.
      --
      -- NOTE: This may be a bit confusing to beginners!
      printProperty (ObjectPatternProperty cs1 n1 (Pattern cs3 cs4 (VariablePattern n2))) | n1 == n2 =
        printProperty (ObjectPatternPropertyPun (cs1 `append` cs3) cs4 n1)

      -- Print an object property as normal.
      printProperty (ObjectPatternProperty cs1 n x') =
        -- The trailing comments of our expression are printed by `printCommaList` after the comma.
        let (x, cs2) = takePatternTrailingComments (processPattern x') in
          ( group $
              printLeadingAttachedComments cs1 <>
              text (identifierText n) <>
              text ": " <>
              printPattern x
          , cs2
          )

      printExtension Nothing = mempty

      -- If we are extending a hole pattern then print the shorthand form.
      printExtension (Just (Pattern cs1 cs2 HolePattern)) =
        (if null ps then mempty else ifFlat (text ", ")) <>
        indent (printLeadingAttachedComments cs1 <> text "_" <> printTrailingAttachedComments cs2) <>
        softline

      printExtension (Just x) =
        -- If the object breaks onto multiple lines then put the bar at the same indentation level
        -- as `{}`.
        (if null ps then text "| " else ifBreakElse (text "| ") (text " | ")) <>
        indent (printPattern x) <>
        softline

  where
    x0 = processPattern x0'

    -- Finishes printing an pattern node by printing leading/trailing attached comments and
    -- parentheses in case we need them.
    build x1 =
      printLeadingAttachedComments (patternLeadingComments x0)
        <> x1
        <> printTrailingAttachedComments (patternTrailingComments x0)

-- Prints a type.
printType :: Type -> Document
printType x0' = build $ case typeNode x0 of
  VariableType n -> text (identifierText n)

  BottomType -> text "!"

  TopType -> text "_"

  VoidType -> text "void"

  FunctionType qs ps t ->
    text "fun" <>
    printQuantifierList FunctionQuantifierContext qs <>
    group (text "(" <> indent (softline <> printCommaList printParameter ps) <> text ")") <>
    text " -> " <>
    printType t
    where
      printParameter x' =
        let (x, cs) = takeTypeTrailingComments (processType x') in
          (printType x, cs)

  ObjectType ps ext -> group $
    text "{" <>
    indent (softline <> printCommaList printProperty ps) <>
    printExtension ext <>
    text "}"
    where
      printProperty (ObjectTypeProperty cs1 n x') =
        -- The trailing comments of our expression are printed by `printCommaList` after the comma.
        let (x, cs2) = takeTypeTrailingComments (processType x') in
          ( group $
              printLeadingAttachedComments cs1 <>
              text (identifierText n) <>
              text ": " <>
              printType x
          , cs2
          )

      printExtension Nothing = mempty

      -- If we are extending a top type then print the shorthand form.
      printExtension (Just (Type cs1 cs2 TopType)) =
        (if null ps then mempty else ifFlat (text ", ")) <>
        indent (printLeadingAttachedComments cs1 <> text "_" <> printTrailingAttachedComments cs2) <>
        softline

      printExtension (Just x) =
        -- If the object breaks onto multiple lines then put the bar at the same indentation level
        -- as `{}`.
        (if null ps then text "| " else ifBreakElse (text "| ") (text " | ")) <>
        indent (printType x) <>
        softline

  -- If we quantify a `FunctionType` or a `QuantifiedType` then we want to inline our quantifiers
  -- in those types.
  QuantifiedType [] t -> printType t
  QuantifiedType qs1 t1 ->
    case typeNode t1 of
      VariableType _ -> normal
      BottomType -> normal
      TopType -> normal
      VoidType -> normal

      -- Unbound quantifiers have different meanings when they are in a `QuantifiedType` and when
      -- they are in a `FunctionType`. An unbound quantifier in a `FunctionType` is treated as a
      -- universal quantifier with a bound of `≥ ⊥`. An unbound quantifier in a `QuantifiedType` is
      -- treated as an existential quantifier.
      --
      -- To avoid changing the semantics of a program we _must not_ inline unbound quantifiers into
      -- a function type.
      FunctionType qs2 ps r ->
        (if not (null existentialQuantifiers) then printQuantifierList TypeQuantifierContext existentialQuantifiers <> text " "
        else mempty)
          <> printType (t1 { typeNode = FunctionType (universalQuantifiers `append` qs2) ps r })

        where
          (_, existentialQuantifiers, universalQuantifiers) =
            foldr
              (\q (unboundComments, acc1, acc2) ->
                case q of
                  Right (QuantifierUnbound _ _ _, _) -> (True, q : acc1, acc2)
                  Right (Quantifier _ _ _ _, _) -> (False, acc1, q : acc2)
                  Left _ | unboundComments -> (unboundComments, q : acc1, acc2)
                  Left _ -> (unboundComments, acc1, q : acc2))
              (False, [], [])
              qs1

      ObjectType _ _ -> normal
      QuantifiedType qs2 t2 -> printType (t1 { typeNode = QuantifiedType (qs1 `append` qs2) t2 })
    where
      normal = printQuantifierList TypeQuantifierContext qs1 <> text " " <> printType t1

  where
    x0 = processType x0'

    -- Finishes printing a type node by printing leading/trailing attached comments and
    -- parentheses in case we need them.
    build x1 =
      printLeadingAttachedComments (typeLeadingComments x0)
        <> x1
        <> printTrailingAttachedComments (typeTrailingComments x0)

data QuantifierContext = TypeQuantifierContext | FunctionQuantifierContext

printQuantifierList :: QuantifierContext -> [CommaListItem Quantifier] -> Document
printQuantifierList _ [] = mempty
printQuantifierList kind qs = group $
  text "<" <> indent (softline <> printCommaList printQuantifier qs) <> text ">"
  where
    printQuantifier (QuantifierUnbound cs1 cs2 n) =
      (printLeadingAttachedComments cs1 <> text (identifierText n), cs2)

    -- If we are in a function quantifier list and we see `T: !` then simplify it to `T`.
    printQuantifier (Quantifier cs1 n Flexible (Type cs2 cs3 BottomType)) | FunctionQuantifierContext <- kind =
      printQuantifier (QuantifierUnbound (cs1 `append` cs2) cs3 n)

    printQuantifier (Quantifier cs1 n k t') =
      let (t, cs2) = takeTypeTrailingComments (processType t') in
      ( printLeadingAttachedComments cs1 <>
        text (identifierText n) <>
        (case k of { Flexible -> text ": "; Rigid -> text " = " }) <>
        printType t
      , cs2
      )

-- Expressions that, when they break, should break onto the next line. The following is an example
-- of an expression which should break onto a new line:
--
-- ```ite
-- let x =
--   a +
--   // Hello, world!
--   b;
-- ```
--
-- The following is an example of an expression which should not break onto a new line:
--
-- ```ite
-- let x = f(
--   // Hello, world!
-- );
-- ```
--
-- The general rule of thumb is that if you want to keep the expression aligned vertically when it
-- breaks you should put it on the next line.
shouldBreakOntoNextLine :: Expression -> Bool
shouldBreakOntoNextLine x = case expressionNode x of
  ConstantExpression _ -> False
  VariableExpression _ -> False
  FunctionExpression _ -> False
  CallExpression _ _ -> False
  ObjectExpression _ _ -> False
  PropertyExpression _ _ _ -> False
  PrefixExpression _ _ -> False
  InfixExpression _ _ _ _ -> True
  ConditionalExpression _ -> False
  BlockExpression _ -> False
  LoopExpression _ -> False
  WrappedExpression _ _ -> False

-- Performs some shallow processing on our expression to turn it into the form we want to print.
processExpression :: Expression -> Expression
processExpression x0 = case expressionNode x0 of
  -- Inline an object extension into our object.
  ObjectExpression ps1 (Just (Expression cs1 cs2 (ObjectExpression ps2 ext))) -> processExpression $
    Expression
      (expressionLeadingComments x0 `append` cs1)
      (cs2 `append` expressionTrailingComments x0)
      (ObjectExpression (ps1 `append` ps2) ext)

  _ -> x0

-- Removes the trailing comments from our `Expression` and returns them. If our expression ends in
-- another expression (like prefix expressions: `-E`) then we take the trailing comments from that
-- as well.
--
-- NOTE: Must call `processExpression` on the pattern we pass to this function first!
takeExpressionTrailingComments :: Expression -> (Expression, [AttachedComment])
takeExpressionTrailingComments x0 =
  case expressionNode x0 of
    ConstantExpression _ -> noTrailingExpression
    VariableExpression _ -> noTrailingExpression
    FunctionExpression _ -> noTrailingExpression
    CallExpression _ _ -> noTrailingExpression
    ObjectExpression _ _ -> noTrailingExpression
    PropertyExpression _ _ _ -> noTrailingExpression
    PrefixExpression op x1 -> trailingExpression (PrefixExpression op) x1
    InfixExpression x1 op cs x2 -> trailingExpression (InfixExpression x1 op cs) x2
    ConditionalExpression _ -> noTrailingExpression
    BlockExpression _ -> noTrailingExpression
    LoopExpression _ -> noTrailingExpression
    WrappedExpression _ _ -> noTrailingExpression
  where
    noTrailingExpression =
      if null (expressionTrailingComments x0) then (x0, [])
      else (x0 { expressionTrailingComments = [] }, expressionTrailingComments x0)

    trailingExpression f x1 =
      case takeExpressionTrailingComments (processExpression x1) of
        (_, []) -> noTrailingExpression
        (x2, cs) ->
          if null (expressionTrailingComments x0) then (x0 { expressionNode = f x2 }, cs)
          else
            ( x0 { expressionTrailingComments = [], expressionNode = f x2 }
            , cs ++ expressionTrailingComments x0
            )

-- Removes the leading comments from our `Expression` and returns them. If our expression begins
-- with another expression (like property expressions: `E.p`) then we take the leading comments from
-- that as well.
--
-- NOTE: Must call `processExpression` on the pattern we pass to this function first!
takeExpressionLeadingComments :: Expression -> ([AttachedComment], Expression)
takeExpressionLeadingComments x0 =
  case expressionNode x0 of
    -- For call expressions and property expressions also move any trailing trivia to be
    -- leading trivia.
    CallExpression x1 xs -> leadingExpressionTakeTrailingToo x1 (\x -> CallExpression x xs)
    PropertyExpression x1 cs p -> leadingExpressionTakeTrailingToo x1 (\x -> PropertyExpression x cs p)
    -- While technically prefix operations don’t have a leading expression we treat them as if they
    -- do for aesthetics.
    PrefixExpression op x1 -> leadingExpression x1 (PrefixExpression op)
    InfixExpression x1 op cs x2 -> leadingExpression x1 (\x -> InfixExpression x op cs x2)

    ConstantExpression _ -> noLeadingExpression
    VariableExpression _ -> noLeadingExpression
    FunctionExpression _ -> noLeadingExpression
    ObjectExpression _ _ -> noLeadingExpression
    ConditionalExpression _ -> noLeadingExpression
    BlockExpression _ -> noLeadingExpression
    LoopExpression _ -> noLeadingExpression
    WrappedExpression _ _ -> noLeadingExpression
  where
    noLeadingExpression =
      if null (expressionLeadingComments x0) then ([], x0)
      else (expressionLeadingComments x0, x0 { expressionLeadingComments = [] })

    leadingExpression x1 f =
      case takeExpressionLeadingComments (processExpression x1) of
        ([], _) -> noLeadingExpression
        (cs, x2) ->
          ( expressionLeadingComments x0 ++ cs
          , x0 { expressionLeadingComments = [], expressionNode = f x2 }
          )

    leadingExpressionTakeTrailingToo x1' f =
      let x1 = processExpression x1' in
        case takeExpressionLeadingComments x1 of
          ([], _) ->
            case takeExpressionTrailingComments x1 of
              (_, []) -> noLeadingExpression
              (x3, cs3) ->
                ( expressionLeadingComments x0 ++ cs3
                , x0 { expressionLeadingComments = [], expressionNode = f x3 }
                )
          (cs2, x2) ->
            case takeExpressionTrailingComments x2 of
              (_, []) ->
                ( expressionLeadingComments x0 ++ cs2
                , x0 { expressionLeadingComments = [], expressionNode = f x2 }
                )
              (x3, cs3) ->
                ( expressionLeadingComments x0 ++ cs2 ++ cs3
                , x0 { expressionLeadingComments = [], expressionNode = f x3 }
                )

-- Performs some shallow processing on our pattern to turn it into the form we want to print.
processPattern :: Pattern -> Pattern
processPattern x0 = case patternNode x0 of
  -- Inline an object extension into our object.
  ObjectPattern ps1 (Just (Pattern cs1 cs2 (ObjectPattern ps2 ext))) -> processPattern $
    Pattern
      (patternLeadingComments x0 `append` cs1)
      (cs2 `append` patternTrailingComments x0)
      (ObjectPattern (ps1 `append` ps2) ext)

  _ -> x0

-- Removes the trailing comments from our `Pattern` and returns them.
--
-- NOTE: Must call `processPattern` on the pattern we pass to this function first!
takePatternTrailingComments :: Pattern -> (Pattern, [AttachedComment])
takePatternTrailingComments x0 =
  case patternNode x0 of
    ConstantPattern _ -> noTrailing
    VariablePattern _ -> noTrailing
    HolePattern -> noTrailing
    ObjectPattern _ _ -> noTrailing
  where
    noTrailing =
      if null (patternTrailingComments x0) then (x0, [])
      else (x0 { patternTrailingComments = [] }, patternTrailingComments x0)

-- Performs some shallow processing on our type to turn it into the form we want to print.
processType :: Type -> Type
processType x0 = case typeNode x0 of
  -- Inline an object extension into our object.
  ObjectType ps1 (Just (Type cs1 cs2 (ObjectType ps2 ext))) -> processType $
    Type
      (typeLeadingComments x0 `append` cs1)
      (cs2 `append` typeTrailingComments x0)
      (ObjectType (ps1 `append` ps2) ext)

  _ -> x0

-- Removes the trailing comments from our `Type` and returns them.
--
-- NOTE: Must call `processType` on the pattern we pass to this function first!
takeTypeTrailingComments :: Type -> (Type, [AttachedComment])
takeTypeTrailingComments x0 =
  case typeNode x0 of
    VariableType _ -> noTrailing
    BottomType -> noTrailing
    TopType -> noTrailing
    VoidType -> noTrailing
    FunctionType qs ps x1 -> trailing (FunctionType qs ps) x1
    ObjectType _ _ -> noTrailing
    QuantifiedType qs x1 -> trailing (QuantifiedType qs) x1
  where
    noTrailing =
      if null (typeTrailingComments x0) then (x0, [])
      else (x0 { typeTrailingComments = [] }, typeTrailingComments x0)

    trailing f x1 =
      case takeTypeTrailingComments (processType x1) of
        (_, []) -> noTrailing
        (x2, cs) ->
          if null (typeTrailingComments x0) then (x0 { typeNode = f x2 }, cs)
          else
            ( x0 { typeTrailingComments = [], typeNode = f x2 }
            , cs ++ typeTrailingComments x0
            )
