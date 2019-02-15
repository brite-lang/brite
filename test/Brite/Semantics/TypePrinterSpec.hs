{-# LANGUAGE OverloadedStrings #-}

module Brite.Semantics.TypePrinterSpec (spec) where

import Brite.Diagnostic
import Brite.Semantics.AST (convertRecoverType)
import Brite.Semantics.Check (checkPolytype)
import Brite.Semantics.TypePrinter (printPolytype)
import Brite.Syntax.Identifier
import Brite.Syntax.Parser (parseType)
import Brite.Syntax.Printer (printCompactType)
import Brite.Syntax.TokenStream (tokenize)
import Data.Foldable (traverse_)
import Data.HashSet (HashSet)
import qualified Data.HashSet as HashSet
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Lazy as Text.Lazy
import qualified Data.Text.Lazy.Builder as Text.Builder
import qualified Data.Text.Lazy.Builder.Custom as Text.Builder
import Test.Hspec

testData :: [(Text, Text)]
testData =
  [ ("X", "X")
  , ("void", "void")
  , ("Bool", "Bool")
  , ("Int", "Int")
  , ("!", "!")
  , ("T", "!")
  , ("fun(X) -> Y", "fun(X) -> Y")
  , ("fun(X) -> fun(Y) -> Z", "fun(X) -> fun(Y) -> Z")
  , ("<T: !> T", "!")
  , ("<T: !, U: !> T", "!")
  , ("fun<T>(T) -> T", "fun<T>(T) -> T")
  , ("fun<T>(T) -> fun(T) -> T", "fun<T>(T) -> fun(T) -> T")
  , ("fun<T>(T) -> Int", "fun<T>(T) -> Int")
  , ("fun<T>(Int) -> T", "fun(Int) -> !")
  , ("fun<T = !>(T) -> Int", "fun(!) -> Int")
  , ("fun<T = !>(Int) -> T", "fun<T = !>(Int) -> T")
  , ("fun(Int) -> !", "fun(Int) -> !")
  , ("fun(!) -> Int", "fun(!) -> Int")
  , ("fun(!) -> !", "fun(!) -> !")
  , ("fun<A, B>(A) -> fun(A) -> fun(B) -> B", "fun<A, B>(A) -> fun(A) -> fun(B) -> B")
  , ("fun<A, B>(A) -> B", "fun<A>(A) -> !")
  , ("fun<T = !, U: fun<V>(T) -> V, T>(U) -> T", "fun<U: fun(!) -> !>(U) -> !")
  , ("fun<T, U: fun<V>(V) -> T>(U) -> U", "fun<U: fun<V>(V) -> !>(U) -> U")
  , ("fun<T = !, U: fun<V>(T) -> V>(U) -> U", "fun<U: fun(!) -> !>(U) -> U")
  , ("fun<T, U: fun<V>(V) -> fun(T) -> T, T>(U) -> T", "fun<T, U: fun<V>(V) -> fun(T) -> T>(U) -> !")
  , ("fun<T, U: fun<V>(V) -> T, T = fun<V>(V) -> V>(U) -> T", "fun<U: fun<V>(V) -> !, T = fun<V>(V) -> V>(U) -> T")
  , ("fun<T, U = fun<V>(V) -> T, T: fun<V>(V) -> V>(U) -> T", "fun(fun<V>(V) -> !) -> fun<V>(V) -> V")
  , ("fun<T, U: fun<V>(V) -> T, T: fun<V>(V) -> V>(U) -> T", "fun<U: fun<V>(V) -> !>(U) -> fun<V>(V) -> V")
  , ("fun<T, U = fun<V>(V) -> T, T = fun<V>(V) -> V>(U) -> T", "fun<T = fun<V>(V) -> V>(fun<V>(V) -> !) -> T")
  , ("fun<T, U: fun<V>(V) -> T>(Int) -> U", "fun(Int) -> fun<V>(V) -> !")
  , ("fun<T, U: fun<V>(V) -> T>(T) -> U", "fun<T>(T) -> fun<V>(V) -> T")
  , ("fun<T, T: fun<V>(V) -> T>(Int) -> T", "fun(Int) -> fun<V>(V) -> !")
  , ("fun<T, T: fun<V>(V) -> T>(T) -> T", "fun<T: fun<V>(V) -> !>(T) -> T")
  , ("fun<T, U: fun<V>(V) -> fun(T) -> T, T>(T) -> U", "fun<T, T2>(T2) -> fun<V>(V) -> fun(T) -> T")
  , ("fun<T, U: fun<V>(V) -> fun(T) -> T, T: fun<V>(V) -> V>(T) -> U", "fun<T, T2: fun<V>(V) -> V>(T2) -> fun<V>(V) -> fun(T) -> T")
  , ("fun<T, V: fun<U: fun<V>(V) -> fun(T) -> T, T>(T) -> U>(V) -> V", "fun<T, V: fun<T2>(T2) -> fun<V>(V) -> fun(T) -> T>(V) -> V")
  , ("fun<T2, T, U: fun<V>(V) -> fun(T) -> T, T>(T2) -> fun(T) -> U", "fun<T2, T, T3>(T2) -> fun(T3) -> fun<V>(V) -> fun(T) -> T")
  , ("fun<T2, T, V: fun<U: fun<V>(V) -> fun(T) -> T, T>(T2) -> fun(T) -> U>(V) -> V", "fun<T2, T, V: fun<T3>(T2) -> fun(T3) -> fun<V>(V) -> fun(T) -> T>(V) -> V")
  , ("fun<A = !, B = fun<V>(V) -> A, A, A2>(A) -> fun(A2) -> B", "fun<A = !, B = fun<V>(V) -> A, A, A2>(A) -> fun(A2) -> B")
  , ("fun<A = !, B = fun<V>(V) -> A, A2, A>(A) -> fun(A2) -> B", "fun<A = !, B = fun<V>(V) -> A, A2, A>(A) -> fun(A2) -> B")
  , ("fun<T = !, U: fun<V>(V) -> T, T, T2>(T) -> fun(T2) -> U", "fun<T = !, T2, T3>(T2) -> fun(T3) -> fun<V>(V) -> T")
  , ("fun<T = !, U: fun<V>(V) -> T, T2, T>(T) -> fun(T2) -> U", "fun<T = !, T2, T3>(T3) -> fun(T2) -> fun<V>(V) -> T")
  , ("fun(fun(!) -> !) -> !", "fun(fun(!) -> !) -> !")
  , ("fun(fun(fun(!) -> !) -> !) -> !", "fun(fun(fun(!) -> !) -> !) -> !")
  , ("fun(fun(fun(fun(!) -> !) -> !) -> !) -> !", "fun(fun(fun(fun(!) -> !) -> !) -> !) -> !")
  , ("fun(X) -> fun<T: fun(X) -> !>(T) -> T", "fun(X) -> fun<T: fun(X) -> !>(T) -> T")
  , ("fun(X) -> fun<T: fun(X) -> fun<T: fun(X) -> !>(T) -> T>(T) -> T", "fun(X) -> fun<T: fun(X) -> fun<T: fun(X) -> !>(T) -> T>(T) -> T")
  , ("fun(fun<T = fun(!) -> X>(T) -> T) -> X", "fun(fun<T = fun(!) -> X>(T) -> T) -> X")
  , ("fun(fun<T = fun(fun<T = fun(!) -> X>(T) -> T) -> X>(T) -> T) -> X", "fun(fun<T = fun(fun<T = fun(!) -> X>(T) -> T) -> X>(T) -> T) -> X")
  , ("fun(fun<T: fun(!) -> !>(T) -> Int) -> Int", "fun(fun<T: fun(!) -> !>(T) -> Int) -> Int")
  , ("{}", "{}")
  , ("{| X}", "{| X}")
  , ("{a: Int, b: Bool}", "{a: Int, b: Bool}")
  , ("{b: Bool, a: Int}", "{b: Bool, a: Int}")
  , ("{a: Int | {a: Bool}}", "{a: Int, a: Bool}")
  , ("{a: Bool | {a: Int}}", "{a: Bool, a: Int}")
  , ("{b: void, a: Int, a: Bool}", "{b: void, a: Int, a: Bool}")
  , ("{a: Int, b: void, a: Bool}", "{a: Int, b: void, a: Bool}")
  , ("{a: Int, a: Bool, b: void}", "{a: Int, a: Bool, b: void}")
  , ("fun({id: fun<T>(T) -> T}) -> {id: fun<T>(T) -> T}", "fun({id: fun<T>(T) -> T}) -> {id: fun<T>(T) -> T}")
  , ("<T: !> {p: T}", "{p: !}")
  , ("<T = !> {p: T}", "<T = !> {p: T}")
  , ("<T: !> {p: T, q: T}", "<T: !> {p: T, q: T}")
  , ("fun<T>({p: T}) -> !", "fun({p: !}) -> !")
  , ("fun<T>({p: T}) -> T", "fun<T>({p: T}) -> T")
  , ("<T = {a: Bool}> {b: Int | T}", "{b: Int, a: Bool}")
  , ("<T = {b: Bool}> {a: Int | T}", "{a: Int, b: Bool}")
  , ("<T = {a: Bool}> {a: Int | T}", "{a: Int, a: Bool}")
  , ("<T = {a: Bool}> {a: Int, b: void | T}", "{a: Int, b: void, a: Bool}")
  , ("<T = {a: Bool}> {b: void, a: Int | T}", "{b: void, a: Int, a: Bool}")
  , ("<T = {a: Bool, b: void}> {a: Int | T}", "{a: Int, a: Bool, b: void}")
  , ("<T = {b: void, a: Bool}> {a: Int | T}", "{a: Int, b: void, a: Bool}")
  , ("<T = {a: Bool, a: void}> {a: Int | T}", "{a: Int, a: Bool, a: void}")
  , ("<T = {a: void}> {a: Int, a: Bool, | T}", "{a: Int, a: Bool, a: void}")
  , ("<U = {a: void}, T = {a: Bool | U}> {a: Int | T}", "{a: Int, a: Bool, a: void}")
  , ("<T = <T: !> {a: T}> {b: Int | T}", "<T = {a: !}> {b: Int | T}")
  , ("<T: <T: !> {a: T}> {b: Int | T}", "{b: Int, a: !}")
  , ("<T: <T: !> {b: T}> {a: Int | T}", "{a: Int, b: !}")
  , ("<T: <T: !> {a: T}> {a: Int | T}", "{a: Int, a: !}")
  , ("<T: <T: !> {a: T}> {a: Int, b: void | T}", "{a: Int, b: void, a: !}")
  , ("<T: <T: !> {a: T}> {b: void, a: Int | T}", "{b: void, a: Int, a: !}")
  , ("<T: <T: !> {a: T, b: void}> {a: Int | T}", "{a: Int, a: !, b: void}")
  , ("<T: <T: !> {b: void, a: T}> {a: Int | T}", "{a: Int, b: void, a: !}")
  , ("<T: <T: !> {a: T, a: void}> {a: Int | T}", "{a: Int, a: !, a: void}")
  , ("<T: <T: !> {a: T}> {a: Int, a: Bool, | T}", "{a: Int, a: Bool, a: !}")
  , ("<U: <T: !> {a: T}, T = {a: Bool | U}> {a: Int | T}", "{a: Int, a: Bool, a: !}")
  , ("<U = {a: void}, T: <T: !> {a: T | U}> {a: Int | T}", "{a: Int, a: !, a: void}")
  , ("<U: <T: !> {a: T}, T: <T: !> {a: T | U}> {a: Int | T}", "{a: Int, a: !, a: !}")
  , ("<T: <T: !> {a: T, a: T}> {a: Int | T}", "{a: Int | <T: !> {a: T, a: T}}")
  , ("<T: <T: !> {b: T, a: T}> {a: Int | T}", "{a: Int | <T: !> {b: T, a: T}}")
  , ("<T: <T: !> {a: T, b: T}> {a: Int | T}", "{a: Int | <T: !> {a: T, b: T}}")
  , ("<T: <T: !> {a: T}> {a: Int, b: Bool | T}", "{a: Int, b: Bool, a: !}")
  , ("{b: Int, a: !}", "{b: Int, a: !}")
  , ("{a: Int | {b: Bool}}", "{a: Int, b: Bool}")
  , ("fun<Type2, Type3>({p: Type2 | Type3}) -> Type2", "fun<Type2>({p: Type2 | !}) -> Type2")
  , ("<T> T", "_")
  , ("<T> fun(T) -> void", "fun(_) -> void")
  , ("<T> fun(void) -> T", "fun(void) -> _")
  , ("<T> fun(T) -> T", "<T> fun(T) -> T")
  , ("<T> fun(void) -> void", "fun(void) -> void")
  , ("<T: !, U = fun<V>(V) -> fun(T) -> T, T> fun(U) -> fun(T) -> T", "<T2> fun<T>(fun<V>(V) -> fun(T) -> T) -> fun(T2) -> T2")
  , ("<T: !, T2: !, U = fun<V>(V) -> {a: T, b: T, c: T2, d: T2}, T> fun(U) -> fun(T) -> T", "<T3> fun<T, T2>(fun<V>(V) -> {a: T, b: T, c: T2, d: T2}) -> fun(T3) -> T3")
  , ("<T: !, U = fun<V>(V) -> {a: T, b: T}, T, T2> fun(U) -> {a: T, b: T, c: T2, d: T2}", "<T2, T3> fun<T>(fun<V>(V) -> {a: T, b: T}) -> {a: T2, b: T2, c: T3, d: T3}")
  , ("<T2, T: !, U = fun<V>(V) -> {a: T, b: T}, T> fun(U) -> {a: T, b: T, c: T2, d: T2}", "<T2, T3> fun<T>(fun<V>(V) -> {a: T, b: T}) -> {a: T3, b: T3, c: T2, d: T2}")
  , ("<T: !, U = fun<V>(V) -> T, T> fun(U) -> {a: T, b: T}", "<T> fun(fun<V>(V) -> !) -> {a: T, b: T}")
  , ("<T: !, U: fun<V>(V) -> T, T> {a: U, b: U, c: T, d: T}", "<U: fun<V>(V) -> !, T> {a: U, b: U, c: T, d: T}")
  , ("<A: !> {t: {t: A}", "{t: {t: !}") -- TODO: Printer loses information here. Should we update
  , ("{t: <A: !> {t: A}", "{t: {t: !}") -- our heuristic to fix this?
  ]

initialContext :: HashSet Identifier
initialContext = HashSet.fromList [unsafeIdentifier "X", unsafeIdentifier "Y", unsafeIdentifier "Z"]

spec :: Spec
spec = do
  flip traverse_ testData $ \(input, expectedOutput) ->
    it (Text.unpack input) $ do
      let (type1, ds1) = runDiagnosticWriter (parseType (tokenize input))
      if null ds1 then return () else error (Text.Builder.toString (foldMap diagnosticMessageMarkdown ds1))
      let (type2, _) = runDiagnosticWriter (checkPolytype initialContext (convertRecoverType type1))
      let actualOutput = Text.Lazy.toStrict (Text.Builder.toLazyText (printCompactType (printPolytype type2)))
      let (type3, _) = runDiagnosticWriter (parseType (tokenize actualOutput))
      let (type4, _) = runDiagnosticWriter (checkPolytype initialContext (convertRecoverType type3))
      let actualOutput2 = Text.Lazy.toStrict (Text.Builder.toLazyText (printCompactType (printPolytype type4)))
      actualOutput `shouldBe` expectedOutput
      actualOutput2 `shouldBe` actualOutput
