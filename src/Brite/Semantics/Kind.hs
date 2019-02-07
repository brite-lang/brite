-- The kind system for Brite. Unlike other higher-kinded systems like in Haskell or Scala, Brite’s
-- kind system features subtyping.
--
-- Currently Brite’s kind system does not include higher-kinded type constructors. That’s complexity
-- we’re not sure we want to add yet. However, we don know that we need at _least_ kinds for object
-- types. We can also the kinds system for numbers which is a nice win.

module Brite.Semantics.Kind
  ( Kind
  , Context
  , newContext
  , value
  , numberValue
  , objectValue
  , bottom
  , unknown
  , subtype
  ) where

import Brite.Semantics.CheckMonad
import Control.Monad.ST
import Data.HashTable.ST.Cuckoo (HashTable)
import qualified Data.HashTable.ST.Cuckoo as HashTable
import Data.Maybe (fromMaybe)
import Data.STRef

-- A kind is the type of a type constructor. Every type in Brite has its own “kind” which dictates
-- how that type may be used. Other languages like Haskell and Scala have kind systems, but what
-- makes the Brite kind system unique is that the Brite kind system supports subtyping of kinds!
--
-- For example, numbers and objects both have special kinds which are subtypes (well, I guess
-- subkinds) of the value kind.
--
-- I (Caleb) drew loose inspiration from [MLsub][1] while writing the implementation for the kind
-- system. Mostly we share names and mathematical properties with MLsub but not much else.
--
-- [1]: https://www.cl.cam.ac.uk/~sd601/papers/mlsub-preprint.pdf
data Kind
  -- An unknown kind is a range of kinds which we narrow through subtyping constraints. See the
  -- documentation on `UnknownKind` for more.
  = Unknown Int

  -- `⊤`
  --
  -- All types which may have some representation at runtime. Also currently serving as our top kind
  -- since all other kinds are subtypes of it.
  | Value

  -- All number values at runtime.
  | NumberValue

  -- All object values at runtime.
  | ObjectValue

  -- `⊥`
  --
  -- The bottom of our kind system.
  | Bottom

-- A value kind.
value :: Kind
value = Value

-- A number value kind.
numberValue :: Kind
numberValue = NumberValue

-- An object value kind.
objectValue :: Kind
objectValue = ObjectValue

-- The bottom kind.
bottom :: Kind
bottom = Bottom

-- Create a new unknown kind in our kind context.
unknown :: Context s -> Check s Kind
unknown context = liftST $ do
  nextID <- readSTRef (kindCounter context)
  writeSTRef (kindCounter context) (nextID + 1)
  return (Unknown nextID)

-- An unknown kind is like a type variable in an ML type system except our kind system supports
-- subtyping. An unknown kind represents a _range_ of kinds instead of a single type. We write an
-- unknown kind, `T`, like this: `K1 <: T <: K2`. Where the `K1` is `T`’s lower bound and `K2`
-- is `T`’s upper bound. `T` can be any kind within that range.
--
-- The lower bound represents the _minimum_ kind that `T` can be. The upper bound represents the
-- _maximum_ kind that `T` can be. When we subtype `T` we _narrow_ `T`’s range based on
-- new constraints.
--
-- An unconstrained `T` has a lower bound of bottom (`⊥`) and an upper bound of top (`⊤`). We write
-- this as `⊥ <: T <: ⊤`. Say we see the constraint `T <: object`. We will first compare `T`’s
-- lower (minimum) bound `⊥ <: object`. Then we will update `T`’s upper bound to reflect that
-- `object` is  the new maximum bound. Now we write `T` as `⊥ <: T <: object`. This range for a
-- constrained `T` is notably smaller than before.
data UnknownKind = UnknownKind
  -- `K1 <: T`
  { lowerBound :: Kind
  -- `T <: K2`
  , upperBound :: Kind
  }

-- An unknown kind with no bounds.
unbounded :: UnknownKind
unbounded = UnknownKind { lowerBound = Bottom, upperBound = Value }

-- The context in which we type-check kinds.
data Context s = Context
  -- A counter which represents the next ID for a kind.
  { kindCounter :: STRef s Int
  -- A table of kind IDs to unknown kinds.
  , unknownKinds :: HashTable s Int UnknownKind
  }

-- Creates a new context.
newContext :: Check s (Context s)
newContext = liftST $ Context <$> newSTRef 0 <*> HashTable.new

-- Performs a subtyping constraint between two kinds and reports if the subtyping constraint passes
-- or fails. We write the subtyping constraint as `T <: U`.
--
-- If one of the kinds is an unknown kind then we will narrow its range to fit the constraint.
subtype :: Context s -> Kind -> Kind -> Check s Bool
subtype context kind1 kind2 = case (kind1, kind2) of
  -- If we have two identical unknown kinds then subtyping is a success!
  (Unknown unknownID1, Unknown unknownID2) | unknownID1 == unknownID2 ->
    return True

  -- TODO: Add tests

  -- number <: T <: value
  -- bottom <: U <: number
  --
  -- number <: T <: U <: number

  -- bottom <: T <: number
  -- number <: U <: value
  --
  -- number <: T <: U <: number

  -- bottom <: T <: value
  -- bottom <: U <: value
  --
  -- bottom <: T <: U <: value

  -- bottom <: T <: U <: value
  -- number
  --
  -- bottom <: T <: U <: number

  -- number
  -- bottom <: T <: U <: value
  --
  -- number <: T <: U <: value

  -- If we have two unknown kinds then make sure they uphold the subtyping constraint and if they do
  -- then link them together.
  (Unknown unknownID1, Unknown unknownID2) -> do
    unknown1 <- liftST $ fromMaybe unbounded <$> HashTable.lookup (unknownKinds context) unknownID1
    unknown2 <- liftST $ fromMaybe unbounded <$> HashTable.lookup (unknownKinds context) unknownID2
    result <- subtype context (lowerBound unknown1) (upperBound unknown2)
    if not result then return False else liftST $ do
      newLowerBound <- leastUpperBound context (lowerBound unknown1) (lowerBound unknown2)
      newUpperBound <- greatestLowerBound context (upperBound unknown1) (upperBound unknown2)
      HashTable.insert (unknownKinds context) unknownID1 (UnknownKind { lowerBound = newLowerBound, upperBound = kind2 })
      HashTable.insert (unknownKinds context) unknownID2 (UnknownKind { lowerBound = kind1, upperBound = newUpperBound })
      return True

  -- If one unknown kind is constrained to be the subtype of a known type then check to see if the
  -- new upper bound is in range and add it as the new upper bound of our unknown kind.
  (Unknown unknownID1, _) -> do
    unknown1 <- liftST $ fromMaybe unbounded <$> HashTable.lookup (unknownKinds context) unknownID1
    result <- subtype context (lowerBound unknown1) kind2
    if not result then return False else liftST $ do
      newUpperBound <- greatestLowerBound context (upperBound unknown1) kind2
      HashTable.insert (unknownKinds context) unknownID1 (unknown1 { upperBound = newUpperBound })
      return True

  -- If one unknown kind is constrained to be the supertype of a known type then check to see if the
  -- new lower bound is in range and add it as the new lower bound of our unknown kind.
  (_, Unknown unknownID2) -> do
    unknown2 <- liftST $ fromMaybe unbounded <$> HashTable.lookup (unknownKinds context) unknownID2
    result <- subtype context kind1 (upperBound unknown2)
    if not result then return False else liftST $ do
      newLowerBound <- leastUpperBound context kind1 (lowerBound unknown2)
      HashTable.insert (unknownKinds context) unknownID2 (unknown2 { lowerBound = newLowerBound })
      return True

  -- Hypothetical “top” kind. Currently `Value` serves as the top kind.
  --
  -- (_, Top) -> return True
  -- (Top, _) -> return False

  -- `Bottom` is the subtype of everything and the supertype of nothing.
  (Bottom, _) -> return True
  (_, Bottom) -> return False

  -- `Value` is equivalent to itself.
  (Value, Value) -> return True

  -- `NumberValue` is a subtype of `Value`.
  (NumberValue, Value) -> return True
  (NumberValue, NumberValue) -> return True
  (_, NumberValue) -> return False

  -- `ObjectValue` is a subtype of `Value`.
  (ObjectValue, Value) -> return True
  (ObjectValue, ObjectValue) -> return True
  (_, ObjectValue) -> return False

-- Finds the smallest kind which is larger than both provided kinds. We use the `⨆` operator to
-- describe this operation. Never returns an unknown kind.
--
-- So when `K1 ⨆ K2 = K3` then both `K1 <: K3` and `K2 <: K3` must hold. `K3` must also be the
-- smallest possible kind to uphold this relation.
--
-- Other ways to think about this relation:
--
-- * Returns a kind which represents `K1` *or* `K2`.
-- * Performs the “union” operation in set theory.
-- * In TypeScript syntax: `K1 | K2`.
--
-- Unknown types behave counterintuitively. We use their `lowerBound` to determine the least upper
-- bound instead of their `upperBound`. See the documentation on `greatestLowerBound` for
-- reasoning why. TL;DR: The smallest upper bound of an unknown type `T` is the smallest upper bound
-- of its lower bound.
leastUpperBound :: Context s -> Kind -> Kind -> ST s Kind
leastUpperBound context kind1 kind2 = case (kind1, kind2) of
  -- NOTE: We use the lower bound of an unknown kind because that’s the least bound of the kind.
  (Unknown unknownID1, _) -> do
    unknown1 <- fromMaybe unbounded <$> HashTable.lookup (unknownKinds context) unknownID1
    leastUpperBound context (lowerBound unknown1) kind2

  -- NOTE: We use the lower bound of an unknown kind because that’s the least bound of the kind.
  (_, Unknown unknownID2) -> do
    unknown2 <- fromMaybe unbounded <$> HashTable.lookup (unknownKinds context) unknownID2
    leastUpperBound context kind1 (lowerBound unknown2)

  (Bottom, _) -> return kind2
  (_, Bottom) -> return kind1

  (Value, Value) -> return kind1

  (NumberValue, Value) -> return kind2
  (Value, NumberValue) -> return kind1
  (NumberValue, NumberValue) -> return kind1

  (ObjectValue, Value) -> return kind2
  (Value, ObjectValue) -> return kind1
  (ObjectValue, ObjectValue) -> return kind1

  (NumberValue, ObjectValue) -> return Value
  (ObjectValue, NumberValue) -> return Value

-- Finds the largest kind which is smaller than both provided kinds. We use the `⨅` operator to
-- describe this operation. Never returns an unknown kind.
--
-- So when `K1 ⨅ K2 = K3` then both `K3 <: K1` and `K3 <: K2` must hold. `K3` must also be the
-- smallest possible kind to uphold this relation.
--
-- Other ways to think about this relation:
--
-- * Returns a kind which represents `K1` *and* `K2`.
-- * Performs the “intersection” operation in set theory.
-- * In TypeScript syntax: `K1 & K2`.
--
-- Unknown kinds behave counterintuitively. Instead of finding a type lower than the unknown type’s
-- _lower_ bound we find a type only lower than the unknown type’s _upper_ bound. Consider the
-- unknown type `T`. `T` is bounded by bottom and top like so `⊥ <: T <: ⊤`. Let `U` be the largest
-- type for which `U <: T` holds. What is `U`? Intuitively, one might say that `⊥` is `U` since that
-- is `T`’s lower bound, but `U` is not bottom! `U` is instead top, `⊤`. Why? Well does `⊥ <: T`
-- hold? It does. Does `⊤ <: T` hold? Well yes, that holds as well. According to our implementation
-- of subtyping, every subtype operation _shrinks_ the range of `T` as long as the new range is a
-- sub-range of the old range. When we run `⊤ <: T` now `T`’s range shrinks to `⊤ <: T <: ⊤` or
-- simply `⊤`. Therefore, the greatest-lower bound of `T` will always be `T`’s upper bound.
greatestLowerBound :: Context s -> Kind -> Kind -> ST s Kind
greatestLowerBound context kind1 kind2 = case (kind1, kind2) of
  -- NOTE: We use the upper bound of an unknown kind because that’s the least bound of the kind.
  (Unknown unknownID1, _) -> do
    unknown1 <- fromMaybe unbounded <$> HashTable.lookup (unknownKinds context) unknownID1
    greatestLowerBound context (upperBound unknown1) kind2

  -- NOTE: We use the upper bound of an unknown kind because that’s the least bound of the kind.
  (_, Unknown unknownID2) -> do
    unknown2 <- fromMaybe unbounded <$> HashTable.lookup (unknownKinds context) unknownID2
    greatestLowerBound context kind1 (upperBound unknown2)

  (Bottom, _) -> return kind1
  (_, Bottom) -> return kind2

  (Value, Value) -> return kind1

  (NumberValue, Value) -> return kind1
  (Value, NumberValue) -> return kind2
  (NumberValue, NumberValue) -> return kind1

  (ObjectValue, Value) -> return kind1
  (Value, ObjectValue) -> return kind2
  (ObjectValue, ObjectValue) -> return kind1

  (NumberValue, ObjectValue) -> return Bottom
  (ObjectValue, NumberValue) -> return Bottom
