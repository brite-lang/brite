-- And Taborlin the Great said to the stone: "BREAK!" and the stone broke...

{-# LANGUAGE OverloadedStrings #-}

module Brite.Semantics.Namer
  ( uniqueName
  , uniqueNameM
  , FreshCounter
  , initialFreshCounter
  , freshTypeName
  , freshTypeNameM
  , isFreshTypeName
  ) where

import Brite.Syntax.Identifier
import Data.Char (isDigit)
import Data.Text (Text)
import qualified Data.Text as Text

-- Generates a unique name based on the provided name. If the name is already unique we return it.
-- If the name is not unique we increments an integer suffix count on the name to create new names.
-- For instance, `x` becomes `x2`, `x2` becomes `x3`, `x3` becomes `x4` and so on. Uses the provided
-- function to check if a name already exists.
uniqueName :: (Identifier -> Bool) -> Identifier -> Identifier
uniqueName exists name | not (exists name) = name
uniqueName exists initialName = loop start
  where
    (start, namePrefix) = case integerSuffix (identifierText initialName) of
      Nothing -> (2, identifierText initialName)
      Just (name, suffix) -> (suffix + 1, name)

    loop i =
      let newName = unsafeIdentifier (Text.append namePrefix (Text.pack (show i))) in
        if exists newName then loop (i + 1) else newName

-- Same as `uniqueName` except the exists check is performed inside a monad in case the
-- programmer needs access to mutable references.
uniqueNameM :: Monad m => (Identifier -> m Bool) -> Identifier -> m Identifier
uniqueNameM exists initialName = do
  initialNameExists <- exists initialName
  if initialNameExists then loop start else return initialName
  where
    (start, namePrefix) = case integerSuffix (identifierText initialName) of
      Nothing -> (2, identifierText initialName)
      Just (name, suffix) -> (suffix + 1, name)

    loop i = do
      let newName = unsafeIdentifier (Text.append namePrefix (Text.pack (show i)))
      newNameExists <- exists newName
      if newNameExists then loop (i + 1) else return newName

-- State for a counter of fresh names.
newtype FreshCounter = FreshCounter Int

-- The initial state for a fresh counter.
initialFreshCounter :: FreshCounter
initialFreshCounter = FreshCounter 1

-- Generates a new name for a type. Takes a function which checks if the name already exists or not
-- and takes some state for generating fresh names.
freshTypeName :: (Identifier -> Bool) -> FreshCounter -> (Identifier, FreshCounter)
freshTypeName exists (FreshCounter j) = loop j
  where
    loop i =
      let newName = unsafeIdentifier (Text.append freshTypeBaseName (Text.pack (show i))) in
        if exists newName then loop (i + 1) else (newName, FreshCounter (i + 1))

-- Same as `freshTypeName` except the exists check is performed inside a monad in case the
-- programmer needs access to mutable references.
freshTypeNameM :: Monad m => (Identifier -> m Bool) -> FreshCounter -> m (Identifier, FreshCounter)
freshTypeNameM exists (FreshCounter j) = loop j
  where
    loop i = do
      let newName = unsafeIdentifier (Text.append freshTypeBaseName (Text.pack (show i)))
      newNameExists <- exists newName
      if newNameExists then loop (i + 1) else return (newName, FreshCounter (i + 1))

-- The base name we use when generating a fresh type variable name when we have no other name
-- to use.
--
-- We choose to name these types `TypeN` where “N” is a positive integer. Other languages may choose
-- `tN` or `TN` or a sequence of `a`, `b`, `c`, etc. We choose `TypeN` because we want to enforce
-- for the programmer that type variable names are just like regular variable names and they should
-- be named as such. A name like `T` (while popular in Java, JavaScript, and C) is not
-- very expressive.
freshTypeBaseName :: Text
freshTypeBaseName = "Type"

-- Was this name generated by our fresh type name machinery?
isFreshTypeName :: Identifier -> Bool
isFreshTypeName name = loop (0 :: Int) (identifierText name)
  where
    loop n t1 = case (n, Text.uncons t1) of
      (0, Just ('T', t2)) -> loop 1 t2
      (1, Just ('y', t2)) -> loop 2 t2
      (2, Just ('p', t2)) -> loop 3 t2
      (3, Just ('e', t2)) -> loop 4 t2
      (4, Just (c, t2)) | isDigit c -> loop 4 t2
      (4, Nothing) -> True
      _ -> False

-- Gets the integer suffix of the provided name. For instance, for `x` we return nothing, but for
-- `x42` we return the integer 42. Also returns the string before the suffix.
integerSuffix :: Text -> Maybe (Text, Int)
integerSuffix text0 =
  case Text.unsnoc text0 of
    Just (text1, '0') -> Just (loop 0 0 text1)
    Just (text1, '1') -> Just (loop 0 1 text1)
    Just (text1, '2') -> Just (loop 0 2 text1)
    Just (text1, '3') -> Just (loop 0 3 text1)
    Just (text1, '4') -> Just (loop 0 4 text1)
    Just (text1, '5') -> Just (loop 0 5 text1)
    Just (text1, '6') -> Just (loop 0 6 text1)
    Just (text1, '7') -> Just (loop 0 7 text1)
    Just (text1, '8') -> Just (loop 0 8 text1)
    Just (text1, '9') -> Just (loop 0 9 text1)
    _ -> Nothing
  where
    loop :: Int -> Int -> Text -> (Text, Int)
    loop k n text1 =
      case Text.unsnoc text1 of
        Just (text2, '0') -> loop (k + 1) (n + (0 * 10 ^ (k + 1))) text2
        Just (text2, '1') -> loop (k + 1) (n + (1 * 10 ^ (k + 1))) text2
        Just (text2, '2') -> loop (k + 1) (n + (2 * 10 ^ (k + 1))) text2
        Just (text2, '3') -> loop (k + 1) (n + (3 * 10 ^ (k + 1))) text2
        Just (text2, '4') -> loop (k + 1) (n + (4 * 10 ^ (k + 1))) text2
        Just (text2, '5') -> loop (k + 1) (n + (5 * 10 ^ (k + 1))) text2
        Just (text2, '6') -> loop (k + 1) (n + (6 * 10 ^ (k + 1))) text2
        Just (text2, '7') -> loop (k + 1) (n + (7 * 10 ^ (k + 1))) text2
        Just (text2, '8') -> loop (k + 1) (n + (8 * 10 ^ (k + 1))) text2
        Just (text2, '9') -> loop (k + 1) (n + (9 * 10 ^ (k + 1))) text2
        _ -> (text1, n)
