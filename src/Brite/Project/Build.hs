-- This module is responsible for running the Brite toolchain when the user invokes it. The Brite
-- toolchain can be thought of as a pipeline:
--
-- 1. Discover source files.
-- 2. Parse source files.
-- 3. Type check source files.
-- 4. Pre-evaluate source files.
-- 5. Compile build units.
--
-- It would be incredibly expensive to run this pipeline every time the user changes their project,
-- but we model the world is if that’s the case as it makes writing the individual steps easier.
-- Then we use caching to drastically speed everything up. This idea was popularized in the User
-- Interface world by React.
--
-- The way Brite works is that every time the user invokes the build command we look at all of their
-- source files and only rebuild the ones which changed. The user may also invoke a “check” command
-- which only type checks their project, skipping steps 4 and 5.
--
-- A user may also choose to narrow the files Brite looks at when rebuilding. If the user supplies
-- a set of paths then Brite will only check these paths for changes and will ignore all other
-- source files in the project. If a source file changed, Brite won’t update the cache with those
-- changes until the user for a build that updates those files.
--
-- In this way the Brite toolchain runner is dumb. It moves the problem of cache invalidation onto
-- the user’s shoulders. If the user never tells Brite to invalidate the cache for a specific file
-- then Brite won’t bother.
--
-- While we are building the cache is locked.
--
-- Then there’s the problem of virtual files. Brite supports IDEs creating “virtual files” while the
-- user is editing. Virtual files only live temporarily, but they are still saved to the cache.
-- Virtual files are never pre-evaluated or compiled. They are only type checked. Virtual files may
-- never have dependents. (Brite disallows dependency cycles between files so a virtual file is
-- never a dependent of itself. This is important and one of the reasons we don’t allow cycles
-- between files.)

module Brite.Project.Build
  ( buildProject
  ) where

import Brite.Project.Files
import Brite.Project.Cache
import Data.Foldable (traverse_)
import qualified Data.HashTable.IO as HashTable
import System.Directory (doesFileExist)

-- TODO: Create C++ bootstrapper to provide arguments to the Haskell RTS. Specifically we’d like to
-- instruct Haskell to use N - 1 threads where N is the number of available concurrent threads. See
-- [`std::thread::hardware_concurrency`][1]. We have to do this in a C++ wrapper because there is no
-- way to [configure the RTS in Haskell][2].
--
-- [1]: https://en.cppreference.com/w/cpp/thread/thread/hardware_concurrency
-- [2]: https://downloads.haskell.org/~ghc/7.4.1/docs/html/users_guide/runtime-control.html

-- We need a hash table with:
--
-- * Reasonable insertion performance considering we do it all at once in one batch.
-- * Good deletion performance since we might delete all the entries we added to the table.
type HashTable k v = HashTable.CuckooHashTable k v

-- Builds _all_ of the source files in a Brite project. If a source file is already up-to-date in
-- the cache then we skip building it.
--
-- If there are any source files in the cache that no longer exist in our project directory then we
-- will delete those source files from the cache. Running full project builds occasionally is
-- important for garbage collection.
--
-- This function executes in an immediate cache transaction. That means no other process can write
-- to the project’s cache until this function completes! Other processes may read stale data from
-- the cache, though. If any part of the transaction fails then the entire thing will be
-- rolled back.
--
-- TODO: Retry transaction commit if we get `SQLITE_BUSY` because that means another process is
-- reading while we are trying to write! We don’t want to throw away our entire transaction just
-- because someone else is reading.
buildProject :: ProjectCache -> IO ()
buildProject cache = withImmediateTransaction cache $ do
  -- Create a new hash table with which we will store in-memory our source file objects after
  -- fetching them from the cache.
  sourceFiles <- HashTable.new :: IO (HashTable SourceFilePath SourceFile)

  -- Select all the source files from our cache and put them into a hash table keyed by the source
  -- file’s path.
  selectAllSourceFiles cache () $ \() sourceFile ->
    HashTable.insert sourceFiles (sourceFilePath sourceFile) sourceFile

  -- Traverse all the source files in our project. If the source file does not exist in our cache
  -- or the source file has been modified since it was inserted in our cache then we need to process
  -- the source file.
  --
  -- We delete all the source files we see from our `sourceFiles` hash table. This means that at the
  -- very end we’ll be left with only the source files which were deleted since the last time we
  -- updated our cache. These source files need to be removed from the cache.
  traverseProjectSourceFiles (projectDirectory cache) () $ \() localSourceFilePath -> do
    -- Lookup the source file in our hash table.
    sourceFileM <- HashTable.lookup sourceFiles localSourceFilePath
    case sourceFileM of
      -- If the source file does not exist then we need to process the source file and insert it
      -- into our cache!
      Nothing -> insertSourceFile cache localSourceFilePath
      -- If the source file does exist in the cache...
      Just sourceFile -> do
        localSourceFileTime <- getSourceFileTime (projectDirectory cache) localSourceFilePath
        -- Check the current modification time of the source file. If it is _later_ then the source
        -- file modification time in our cache then we need to update the source file in our cache.
        if sourceFileTime sourceFile < localSourceFileTime then updateSourceFile cache sourceFile
        else return ()
        -- Delete the source file from our hash table. All the source files which remain in our hash
        -- table at the end of our project build will be deleted from the cache.
        HashTable.delete sourceFiles localSourceFilePath

  -- Delete all source files in the cache that still exist in our `sourceFiles` hash table. If a
  -- source file was not deleted from our hash table then that means it does not exist in the
  -- file system.
  HashTable.mapM_ (\(_, sourceFile) -> deleteSourceFile cache sourceFile) sourceFiles

  return ()

-- Builds a subset of the source files in a project. We only update the source files that we were
-- provided in the cache. We do not touch any other source files. Except possibly the dependents of
-- the source files we are updating.
--
-- If we provide the name of a source file path which no longer exists in the file system but does
-- exist in the cache then we will remove the cache entry. This is how one may perform manual
-- garbage collection. Source file paths which don’t exist in the file system or in the cache
-- are ignored.
--
-- TODO: Retry transaction commit if we get `SQLITE_BUSY` because that means another process is
-- reading while we are trying to write! We don’t want to throw away our entire transaction just
-- because someone else is reading.
buildProjectFiles :: ProjectCache -> [SourceFilePath] -> IO ()
buildProjectFiles cache targetedSourceFilePaths = withImmediateTransaction cache $ do
  -- Create a new hash table with which we will store in-memory our source file objects after
  -- fetching them from the cache.
  sourceFiles <- HashTable.new :: IO (HashTable SourceFilePath SourceFile)

  -- Select the targeted source files from our cache and put them into a hash table keyed by the
  -- source file’s path.
  selectSourceFiles cache targetedSourceFilePaths () $ \() sourceFile ->
    HashTable.insert sourceFiles (sourceFilePath sourceFile) sourceFile

  -- Traverse the targeted source files...
  flip traverse_ targetedSourceFilePaths $ \targetedSourceFilePath -> do
    -- Lookup the source file in our file system and in the results of our cache database query.
    targetedSourceFileExists <- doesFileExist (getSourceFilePath (projectDirectory cache) targetedSourceFilePath)
    sourceFileM <- HashTable.lookup sourceFiles targetedSourceFilePath
    -- Perform an action based on the state of our file system and cache...
    case (targetedSourceFileExists, sourceFileM) of
      -- If the file does not exist in the file system _and_ the file does not exist in our cache
      -- then do nothing.
      (False, Nothing) -> return ()
      -- If the file exists in our file system and the file does not exist in our cache then build
      -- the file and insert it into our cache.
      (True, Nothing) -> insertSourceFile cache targetedSourceFilePath
      -- If the file does not exist in our file system but the file does exist in our cache then
      -- remove the file from the cache.
      (False, Just sourceFile) -> deleteSourceFile cache sourceFile
      -- If the file exists in both the file system and our cache then let’s check the targeted
      -- file’s modification time. If the modification time is later then what we have in our cache
      -- then let’s update the source file in our cache.
      (True, Just sourceFile) -> do
        targetedSourceFileTime <- getSourceFileTime (projectDirectory cache) targetedSourceFilePath
        -- Check the current modification time of the source file. If it is _later_ then the source
        -- file modification time in our cache then we need to update the source file in our cache.
        if sourceFileTime sourceFile < targetedSourceFileTime then updateSourceFile cache sourceFile
        else return ()

-- TODO: `buildProjectVirtualFiles`

-- Builds a source file which does not exist in the cache and inserts it into the cache.
--
-- Assumes that:
--
-- * The source file does not exist in our cache.
-- * The source file exists in the file system.
-- * That we are inside an immediate transaction.
insertSourceFile :: ProjectCache -> SourceFilePath -> IO ()
insertSourceFile = error "TODO: unimplemented"

-- Rebuilds a source file which already exists in the cache and updates all the cache entries
-- associated with that source file.
--
-- Assumes that:
--
-- * The source file exists in our cache.
-- * The source file exists in the file system.
-- * The cached version of the source file is out-of-date with the file system version.
-- * That we are inside an immediate transaction.
updateSourceFile :: ProjectCache -> SourceFile -> IO ()
updateSourceFile = error "TODO: unimplemented"

-- Deletes a source file and all associated resources from the cache.
--
-- Assumes that:
--
-- * The source file exists in our cache.
-- * The source file does not exist in the file system.
-- * That we are inside an immediate transaction.
deleteSourceFile :: ProjectCache -> SourceFile -> IO ()
deleteSourceFile = error "TODO: unimplemented"
