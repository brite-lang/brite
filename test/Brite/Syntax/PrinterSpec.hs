{-# LANGUAGE OverloadedStrings #-}

module Brite.Syntax.PrinterSpec (spec) where

import Brite.Diagnostics
import Brite.Syntax.Parser
import Brite.Syntax.Printer
import Brite.Syntax.Tokens
import qualified Data.Text as T
import qualified Data.Text.Lazy as L
import qualified Data.Text.Lazy.Builder as B
import Test.Hspec
import System.IO

testData :: [T.Text]
testData =
  [ "true"
  , "false"
  , "true false"
  , "true false true"
  ]

openSnapshotFile :: IO Handle
openSnapshotFile = do
  h <- openFile "test/Brite/Syntax/PrinterSpecSnapshot.md" WriteMode
  hPutStrLn h "# PrinterSpecSnapshot"
  return h

closeSnapshotFile :: Handle -> IO ()
closeSnapshotFile h = do
  hPutStrLn h ""
  hPutStrLn h (replicate 80 '-')
  hClose h

spec :: Spec
spec = beforeAll openSnapshotFile $ afterAll closeSnapshotFile $ do
  flip mapM_ testData $ \input ->
    it (T.unpack (escape input)) $ \h ->
      let
        (module_, _) = runDiagnosticWriter (parseModule (tokenize input))
        output = printModule module_
      in do
        hPutStrLn h ""
        hPutStrLn h (replicate 80 '-')
        hPutStrLn h ""
        hPutStrLn h "### Input"
        hPutStrLn h "```ite"
        hPutStrLn h (T.unpack input)
        hPutStrLn h "```"
        hPutStrLn h ""
        hPutStrLn h "### Output"
        hPutStrLn h "```"
        hPutStr h (L.unpack (B.toLazyText output))
        hPutStrLn h "```"

escape :: T.Text -> T.Text
escape = T.concatMap
  (\c ->
    case c of
      '\n' -> "\\n"
      _ -> T.singleton c)