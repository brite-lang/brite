{-# LANGUAGE Rank2Types #-}

module Brite.Parser.Framework3
  ( Parser
  , runParser
  , glyph
  , keyword
  , identifier
  ) where

import Prelude hiding (sequence)
import Brite.Diagnostics
import Brite.Source
import Data.Maybe

newtype Parser a = Parser
  { unParser :: forall b. TokenList -> ParserOk a b -> ParserErr a b -> DiagnosticWriter b
  }

type ParserOk a b = TokenList -> a -> DiagnosticWriter b

type ParserErr a b = TokenList -> DiagnosticWriter a -> ParserErrCont b -> DiagnosticWriter b

newtype ParserErrCont b = ParserErrCont { continue :: TokenList -> DiagnosticWriter b }

instance Functor Parser where
  fmap f p = Parser (\ts0 ok err ->
    unParser p ts0
      (\ts1 x -> ok ts1 (f x))
      (\ts1 x k -> err ts1 (f <$> x) k))

instance Applicative Parser where
  pure a = Parser (\ts ok _ -> ok ts a)
  (<*>) = sequence

runParser :: Parser a -> TokenList -> DiagnosticWriter a
runParser p ts0 =
  unParser p ts0
    (\_ a -> return a)
    (\ts1 a k ->
      case ts1 of
        NextToken _ _ ts2 -> continue k ts2
        EndToken _ -> a)

glyph :: Glyph -> Parser (Either Diagnostic Range)
glyph g = fmap (fmap fst) $ terminal (ExpectedGlyph g) $ \t ->
  case t of
    Glyph g' | g == g' -> Just ()
    _ -> Nothing

keyword :: Keyword -> Parser (Either Diagnostic Range)
keyword k = glyph (Keyword k)

identifier :: Parser (Either Diagnostic (Range, Identifier))
identifier = terminal ExpectedIdentifier $ \t ->
  case t of
    IdentifierToken ident -> Just ident
    _ -> Nothing

terminal :: ExpectedToken -> (Token -> Maybe a) -> Parser (Either Diagnostic (Range, a))
terminal ex parse = Parser (run Nothing)
  where
    run e ts1 ok err =
      case ts1 of
        NextToken r t ts2 ->
          case parse t of
            Just a -> ok ts2 $ Right (r, a)
            Nothing ->
              case t of
                -- If we see an unexpected character we assume no one can handle it, so report
                -- an error and immediately try again.
                --
                -- Call `run` with the first reported error.
                UnexpectedChar _ -> do
                  e' <- unexpectedToken r t ex
                  run (Just (fromMaybe e' e)) ts2 ok err

                _ ->
                  -- Call the error callback so that we may attempt recovery. The error value either
                  -- uses the first reported error while calling `run` or it reports its own error.
                  --
                  -- If the continuation is called then we report an error and call `run` with the
                  -- first reported error.
                  err ts1
                    (Left <$> maybe (unexpectedToken r t ex) return e)
                    (ParserErrCont (\ts3 -> do
                      e' <- unexpectedToken r t ex
                      run (Just (fromMaybe e' e)) ts3 ok err))

        EndToken p ->
          -- Call the error callback so that we may attempt recovery. The error value either uses
          -- the first reported error while calling `run` or it reports its own error.
          --
          -- The continuation should never be used since we’re at the end. There are no more tokens
          -- to retry.
          err ts1
            (Left <$> maybe (unexpectedEnding (Range p p) ex) return e)
            (error "unused")

sequence :: Parser (a -> b) -> Parser a -> Parser b
sequence p1 p2 = Parser $ \ts0 ok err ->
  -- Run the first parser.
  unParser p1 ts0

    -- If the first parser succeeds:
    (\ts1 f ->
      -- Run the second parser. If it succeeds call our “ok” callback. If it fails call our
      -- “err” callback.
      unParser p2 ts1
        (\ts2 a -> ok ts2 (f a))
        (\ts2 a k -> err ts2 (f <$> a) k))

    -- If the first parser fails:
    (\ts1 f k ->
      -- Run the second parser. If it suceeds we can recover from our first parser’s error! If it
      -- fails call our “err” callback.
      unParser p2 ts1
        (\ts2 a -> f >>= \f' -> ok ts2 (f' a))
        (\ts2 a _ -> err ts2 (f <*> a) k))
