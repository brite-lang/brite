module Brite.Semantics.Prefix
  ( Prefix
  , newPrefix
  ) where

import Brite.Semantics.Type
import Control.Monad.ST
import Data.HashTable.ST.Cuckoo (HashTable)
import qualified Data.HashTable.ST.Cuckoo as HashTable
import Data.STRef

-- The prefix manages all the type variables we create during type checking. The prefix uses the
-- `ST` monad for mutability. Unlike other immutable Haskell data types.
--
-- The prefix gets its name from the theory of a polytype “prefix” in the [MLF thesis][1]. See
-- Section 1.2 for an introduction to prefixes in theory. From the thesis:
--
-- > A prefix `Q` is a sequence of bindings `(a1 x o1)...(an x on)`
--
-- Our prefix, in theory, is also a sequence of bindings, however, from just a casual observation
-- one will note that the type is a bit more complex then that. You see, throughout our type system
-- there are a number of complicated set operations that we must perform on prefixes. For instance,
-- in the `infer()` algorithm (Section 7.1) the MLF thesis uses a “split” operation to add
-- quantifiers back to a type. Operations like this are expensive if we literally implement them on
-- a sequence of bindings, so instead we implement them with our type.
--
-- Our prefix takes a page from traditional ML level-based type checkers. Like the one described in
-- [“How the OCaml type checker works -- or what polymorphism and garbage collection have
-- in common”.][2] The section on “Unsound generalization as memory mismanagement” is particularly
-- applicable to explaining why our implementation is a bit complex.
--
-- We maintain a stack of “levels” in our prefix. Every time we create a type variable we add it to
-- the top level in our level stack. When we pop the level off our level stack we remove all the
-- type variables inside of that level from our prefix. If we update a type variable from an earlier
-- level in the stack with a type variable from a later level in the stack then we move the type
-- variable from later in the stack up to the earliest level. This way we won’t have a dangling type
-- variable pointer. (See, memory mismanagement!)
--
-- [1]: https://pastel.archives-ouvertes.fr/file/index/docid/47191/filename/tel-00007132.pdf
-- [2]: http://okmij.org/ftp/ML/generalization.html
data Prefix s = Prefix
  { prefixCounter :: STRef s Int
  , prefixLevels :: STRef s [PrefixLevel s]
  , prefixEntries :: HashTable s Int (PrefixEntry s)
  }

-- An entry for a type variable in the prefix. The entry remembers the level at which the entry is
-- stored and the quantifier which defined this type variable.
data PrefixEntry s = PrefixEntry
  { prefixEntryLevel :: STRef s (PrefixLevel s)
  , prefixEntryBinding :: Binding
  }

-- In our prefix, levels are a way to manage garbage collection. Whenever we introduce a type
-- variable into our prefix that type variable has a lifetime. That lifetime is expressed by its
-- level. Whenever the type variable’s level is removed from the prefix’s level stack then the type
-- variable is removed from the prefix entirely.
--
-- However, sometimes the programmer will update a type so that a type with a longer lifetime
-- depends on it. When that happens we change the level of the type variable.
data PrefixLevel s = PrefixLevel
  { prefixLevelIndex :: Int
  , prefixLevelTypeVariables :: HashTable s Int ()
  }

-- Creates a new prefix.
newPrefix :: ST s (Prefix s)
newPrefix = Prefix <$> newSTRef 0 <*> newSTRef [] <*> HashTable.new
