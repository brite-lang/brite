{-# LANGUAGE OverloadedStrings #-}

module Brite.Syntax.ParserSpec (spec) where

import Brite.Diagnostic
import qualified Brite.Semantics.AST as AST
import qualified Brite.Semantics.ASTDebug as AST
import qualified Brite.Syntax.CST as CST
import Brite.Syntax.Parser
import Brite.Syntax.TokenStream
import qualified Data.Sequence as Seq
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Lazy as Text.Lazy
import qualified Data.Text.Lazy.Builder as Text.Builder
import System.IO
import Test.Hspec

testData :: [Text]
testData =
  [ "let x = y;"
  , "let x = y"
  , "let"
  , "let x"
  , "let ="
  , "let y"
  , "let ;"
  , "let x ="
  , "let x y"
  , "let x ;"
  , "let = y"
  , "let = ;"
  , "😈 let x = y;"
  , "let 😈 x = y;"
  , "let x 😈 = y;"
  , "let x = 😈 y;"
  , "let x = y 😈;"
  , "let x = y; 😈"
  , "let x = y 😈"
  , ") let x = y;"
  , "let ) x = y;"
  , "let x ) = y;"
  , "let x = ) y;"
  , "let x = y );"
  , "let x = y; )"
  , "let x = y )"
  , "let 😈 = y;"
  , "let x 😈 y;"
  , "let x = 😈;"
  , "let 😈 y;"
  , "let 😈 =;"
  , "let x 😈;"
  , "let = 😈;"
  , "let 😈;"
  , "let ) = y;"
  , "let x ) y;"
  , "let x = );"
  , "let ) y;"
  , "let ) =;"
  , "let x );"
  , "let = );"
  , "let );"
  , "x"
  , "x;"
  , "😈 x"
  , "x 😈"
  , "😈 x;"
  , "x 😈;"
  , "x; 😈"
  , "="
  , "😈"
  , ")"
  , ";"
  , "true"
  , "false"
  , "true true"
  , "("
  , "(x"
  , "()"
  , "(x)"
  , "x)"
  , "(x;"
  , "let x = (y);"
  , "let x = (y;"
  , "let x = y; let x = y;"
  , "let x = y; let x = y; let x = y;"
  , "let x = y; let x = y; let x = y; let x = y;"
  , "let x = y let x = y"
  , "let x = y let x = y let x = y"
  , "let x = y let x = y let x = y let x = y"
  , "let x = y\nlet x = y"
  , "let x = y\nlet x = y\nlet x = y"
  , "let x = y\nlet x = y\nlet x = y\nlet x = y"
  , "😈 let x = y; let x = y; let x = y;"
  , "let x = y; 😈 let x = y; let x = y;"
  , "let x = y; let x = y; 😈 let x = y;"
  , "let x = y; let x = y; let x = y; 😈"
  , "😈 let x = y let x = y let x = y"
  , "let x = y 😈 let x = y let x = y"
  , "let x = y let x = y 😈 let x = y"
  , "let x = y let x = y let x = y 😈"
  , ") let x = y; let x = y; let x = y;"
  , "let x = y; ) let x = y; let x = y;"
  , "let x = y; let x = y; ) let x = y;"
  , "let x = y; let x = y; let x = y; )"
  , ") let x = y let x = y let x = y"
  , "let x = y ) let x = y let x = y"
  , "let x = y let x = y ) let x = y"
  , "let x = y let x = y let x = y )"
  , "do {}"
  , "do { "
  , "do }"
  , "do } do }"
  , "do"
  , "do do"
  , "do { let x = y; }"
  , "do { let x = y; "
  , "do let x = y; }"
  , "do let x = y }"
  , "do let x = y;"
  , "do let x = y"
  , "let x = (do {);"
  , "let x = (do { let y = z; );"
  , "let x = (do);"
  , "let x = (do let y = z; );"
  , "let x = (do { let y = z );"
  , "let x = (do { let y = );"
  , "do { let x = y; }"
  , "do { let x = y }"
  , "do { let x = y; let x = y; }"
  , "do { let x = y; let x = y; let x = y; }"
  , "do { let x = y; let x = y; let x = y; let x = y; }"
  , "do { let x = y let x = y }"
  , "do { let x = y let x = y let x = y }"
  , "do { let x = y let x = y let x = y let x = y }"
  , "do { let x = y\nlet x = y\n }"
  , "do { let x = y\nlet x = y\nlet x = y\n }"
  , "do { let x = y\nlet x = y\nlet x = y\nlet x = y\n }"
  , "do { 😈 let x = y; let x = y; let x = y; }"
  , "do { let x = y; 😈 let x = y; let x = y; }"
  , "do { let x = y; let x = y; 😈 let x = y; }"
  , "do { let x = y; let x = y; let x = y; 😈 }"
  , "do { 😈 let x = y let x = y let x = y }"
  , "do { let x = y 😈 let x = y let x = y }"
  , "do { let x = y let x = y 😈 let x = y }"
  , "do { let x = y let x = y let x = y 😈 }"
  , "do { ) let x = y; let x = y; let x = y; }"
  , "do { let x = y; ) let x = y; let x = y; }"
  , "do { let x = y; let x = y; ) let x = y; }"
  , "do { let x = y; let x = y; let x = y; ) }"
  , "do { ) let x = y let x = y let x = y }"
  , "do { let x = y ) let x = y let x = y }"
  , "do { let x = y let x = y ) let x = y }"
  , "do { let x = y let x = y let x = y ) }"
  , "let x = ) let x = )"
  , "let x = ) )"
  , ") let x = )"
  , "let x = ) ) let x = )"
  , "do do 😈"
  , "do do )"
  , "if x {}"
  , "if x { y }"
  , "if x {} else {}"
  , "if x { y } else {}"
  , "if x {} else { y }"
  , "if x { y } else { z }"
  , "if { let x = y }"
  , "if {}"
  , "if x }"
  , "if x {"
  , "if x"
  , "if {"
  , "if }"
  , "if {} else {}"
  , "if x } else {}"
  , "if x { else {}"
  , "if x else {}"
  , "if { else {}"
  , "if } else {}"
  , "if {} {}"
  , "if x } {}"
  , "if x { {}"
  , "if { {}"
  , "if } {}"
  , "if {} else }"
  , "if x } else }"
  , "if x { else }"
  , "if x else }"
  , "if { else }"
  , "if } else }"
  , "if {} else {"
  , "if x } else {"
  , "if x { else {"
  , "if x else {"
  , "if { else {"
  , "if } else {"
  , "if {} else"
  , "if x } else"
  , "if x { else"
  , "if x else"
  , "if { else"
  , "if } else"
  , "if {} {"
  , "if x } {"
  , "if x { {"
  , "if x {"
  , "if { {"
  , "if } {"
  , "if {} }"
  , "if x } }"
  , "if x { }"
  , "if x }"
  , "if { }"
  , "if } }"
  , "x 😈 😈 ;"
  , "x ) ) ;"
  , "let 😈 😈 x = y;"
  , "let ) ) x = y;"
  , "😈 😈"
  , ") )"
  , "if x {} { let y = z }"
  , "o.p"
  , "o.p.q"
  , "o."
  , "o.p."
  , "o..p"
  , "o p"
  , "o😈.p"
  , "o.😈p"
  , "o.😈p.q"
  , "o.p😈.q"
  , "o.p.😈q"
  , "o).p"
  , "o.)p"
  , "o.)p.q"
  , "o.p).q"
  , "o.p.)q"
  , "if x {} 😈"
  , "if x {} 😈 else {}"
  , "if x {} )"
  , "if x {} ) else {}"
  , "if 😈 x {}"
  , "if x 😈 {}"
  , "if ) x {}"
  , "if x ) {}"
  , "do {}.p"
  , "if x {}.p"
  , "if x {} else {}.p"
  , "f()"
  , "f ()"
  , "f😈()"
  , "f)()"
  , "f\n()"
  , "f;()"
  , "f\n😈()"
  , "f😈\n()"
  , "f\n)()"
  , "f)\n()"
  , "f(😈)"
  , "f("
  , "😈.p"
  , "(😈.p)"
  , "let 😈) = y;"
  , "let )😈 = y;"
  , "let 😈)x = y;"
  , "let )😈x = y;"
  , "let x = y 😈);"
  , "let x = y )😈;"
  , ")😈 let x = y;"
  , "😈) let x = y;"
  , "let x = y; )😈"
  , "let x = y; 😈)"
  , ")😈"
  , "😈)"
  , "let x = 🐶🐱 y;"
  , "if x {} 🐶🐱 else {}"
  , "if x {} 🐶🐱 else {"
  , "let x = y; do { let x = y; 😈 let x = y; } let x = y;"
  , "let x = 😈 let x = y"
  , "f(x)"
  , "f\n(x)"
  , "f;(x)"
  , "f(a)"
  , "f(a😈)"
  , "f(a})"
  , "f(a😈})"
  , "f(a}😈)"
  , "f(a😈,)"
  , "f(a},)"
  , "f(a😈},)"
  , "f(a}😈,)"
  , "f(a😈, b)"
  , "f(a}, b)"
  , "f(a😈}, b)"
  , "f(a}😈, b)"
  , "f(a😈, b.)" -- NOTE: `b.` is used here and below to enter “yield” mode for the expression.
  , "f(a}, b.)"
  , "f(a😈}, b.)"
  , "f(a}😈, b.)"
  , "f(a😈 b)"
  , "f(a} b)"
  , "f(a😈} b)"
  , "f(a}😈 b)"
  , "f(a😈 b.)"
  , "f(a} b.)"
  , "f(a😈} b.)"
  , "f(a}😈 b.)"
  , "f(a, b)"
  , "f(a, b😈)"
  , "f(a, b})"
  , "f(a, b}😈)"
  , "f(a, b😈})"
  , "f(a, b😈,)"
  , "f(a, b},)"
  , "f(a, b}😈,)"
  , "f(a, b😈},)"
  , "f(a, b😈, c)"
  , "f(a, b}, c)"
  , "f(a, b}😈, c)"
  , "f(a, b😈}, c)"
  , "f(a, b😈, c.)"
  , "f(a, b}, c.)"
  , "f(a, b}😈, c.)"
  , "f(a, b😈}, c.)"
  , "f(a, b😈 c)"
  , "f(a, b} c)"
  , "f(a, b}😈 c)"
  , "f(a, b😈} c)"
  , "f(a, b😈 c.)"
  , "f(a, b} c.)"
  , "f(a, b}😈 c.)"
  , "f(a, b😈} c.)"
  , "f(a.)"
  , "f(a.,)"
  , "f(a., b)"
  , "f(a. (b))"
  , "f(a. (b).)"
  , "f(a.😈)"
  , "f(a.})"
  , "f(a.😈})"
  , "f(a.}😈)"
  , "f(a, b.)"
  , "f(a, b.,)"
  , "f(a, b., c)"
  , "f(a, b. (c))"
  , "f(a, b. (c).)"
  , "f(a, b.😈)"
  , "f(a, b.})"
  , "f(a, b.😈})"
  , "f(a, b.}😈)"
  , "f(😈)"
  , "f(})"
  , "f(😈})"
  , "f(}😈)"
  , "f(a, 😈)"
  , "f(a, })"
  , "f(a, 😈})"
  , "f(a, }😈)"
  , "f(a b)"
  , "f(a, b c)"
  , "f(a b, c)"
  , "f(a b c)"
  , "f(a b, c, d)"
  , "f(a, b c, d)"
  , "f(a, b, c d)"
  , "f(a b c, d)"
  , "f(a, b c d)"
  , "f(a b, c d)"
  , "f(a b c d)"
  , "f(a,, b)"
  , "f(a,, b, c)"
  , "f(a, b,, c)"
  , "f(a,, b,, c)"
  , "f(a,, b, c, d)"
  , "f(a, b,, c, d)"
  , "f(a, b, c,, d)"
  , "f(a, b,, c,, d)"
  , "f(a,, b, c,, d)"
  , "f(a,, b,, c, d)"
  , "f(a,, b,, c,, d)"
  , "f(a, b, c, d,)"
  , "f(a, b, c, d,,)"
  , "f(a, b, c,,)"
  , "f(a, b,,)"
  , "f(a,,)"
  , "f(a, 😈, c)"
  , "f(😈, b, c)"
  , "f(a, b, 😈)"
  , "f(a, }, c)"
  , "f(}, b, c)"
  , "f(a, b, })"
  , "f(a, 😈}, c)"
  , "f(😈}, b, c)"
  , "f(a, b, 😈})"
  , "f(a, }😈, c)"
  , "f(}😈, b, c)"
  , "f(a, b, }😈)"
  , "f(a, b😈, c)"
  , "f(a😈, b, c)"
  , "f(a, b, c😈)"
  , "f(a, b}, c)"
  , "f(a}, b, c)"
  , "f(a, b, c})"
  , "f(a, b😈}, c)"
  , "f(a😈}, b, c)"
  , "f(a, b, c😈})"
  , "f(a, b}😈, c)"
  , "f(a}😈, b, c)"
  , "f(a, b, c}😈)"
  , "f(a, 😈b, c)"
  , "f(😈a, b, c)"
  , "f(a, b, 😈c)"
  , "f(a, }b, c)"
  , "f(}a, b, c)"
  , "f(a, b, }c)"
  , "f(a, 😈}b, c)"
  , "f(😈}a, b, c)"
  , "f(a, b, 😈}c)"
  , "f(a, }😈b, c)"
  , "f(}😈a, b, c)"
  , "f(a, b, }😈c)"
  , "f(a, 😈b}, c)"
  , "f(😈a}, b, c)"
  , "f(a, b, 😈c})"
  , "f(a, }b😈, c)"
  , "f(}a😈, b, c)"
  , "f(a, b, }c😈)"
  , "f(, a)"
  , "f(, a, b)"
  , "f(, a, b, c)"
  , "f(a,)"
  , "f(,)"
  , "f()"
  , "f(a)"
  , "f(a,)"
  , "f(a, b)"
  , "f(a, b,)"
  , "f(a, b, c)"
  , "f(a, b, c,)"
  , "let _ = x;"
  , "let x = _;"
  , "let _ = _;"
  , "fun() {}"
  , "(fun() {})"
  , "fun f() {}"
  , "fun(a) {}"
  , "(fun(a) {})"
  , "fun(a, b) {}"
  , "fun(a, b, c) {}"
  , "(fun(a, b) {})"
  , "(fun(a, b, c) {})"
  , "fun f(a) {}"
  , "fun f(a, b) {}"
  , "fun f(a, b, c) {}"
  , "fun(a,) {}"
  , "fun(a, b,) {}"
  , "fun(a, b, c,) {}"
  , "(fun(a,) {})"
  , "(fun(a, b,) {})"
  , "(fun(a, b, c,) {})"
  , "fun f(a,) {}"
  , "fun f(a, b,) {}"
  , "fun f(a, b, c,) {}"
  , "fun() { let x = y; }"
  , "(fun() { let x = y; })"
  , "fun f() { let x = y; }"
  , "fun() {}()" -- TODO: This should be a call expression
  , "(fun() {}())"
  , "(fun() {})()"
  , "let f = fun() {};"
  , "let f = fun f() {};"
  , "let f = fun(a) {};"
  , "let f = fun(a, b) {};"
  , "let f = fun(a, b, c) {};"
  , "let f = fun f(a) {};"
  , "let f = fun f(a, b) {};"
  , "let f = fun f(a, b, c) {};"
  , "let f = fun(a,) {};"
  , "let f = fun(a, b,) {};"
  , "let f = fun(a, b, c,) {};"
  , "let f = fun f(a,) {};"
  , "let f = fun f(a, b,) {};"
  , "let f = fun f(a, b, c,) {};"
  , "let f = fun() { let x = y; };"
  , "let f = fun f() { let x = y; };"
  , "let f = fun() {}();"
  , "let f = (fun() {})();"
  , "fun f() {}"
  , "fun f) {}"
  , "fun f( {}"
  , "fun f( { let x = y }"
  , "fun f() }"
  , "fun f() {"
  , "fun) {}"
  , "fun( {}"
  , "fun() }"
  , "fun() {"
  , "fun(a, b let x = y; }"
  , "(fun) {})"
  , "(fun( {})"
  , "(fun() })"
  , "(fun() {)"
  , "(fun(a, b let x = y; })"
  , "fun f(a, b let x = y; }"
  , "fun 😈 f() {}"
  , "fun f😈() {}"
  , "fun f(😈) {}"
  , "fun f() 😈 {}"
  , "fun f() {😈}"
  , "fun ] f() {}"
  , "fun f]() {}"
  , "fun f(]) {}"
  , "fun f() ] {}"
  , "fun f() {]}"
  , "fun f(,) {}"
  , "return"
  , "return x"
  , "return\nx"
  , "return;"
  , "return;x"
  , "return x;"
  , "return 😈 x;"
  , "return\n😈 x;"
  , "return 😈\nx;"
  , "return ) x;"
  , "return\n) x;"
  , "return )\nx;"
  , "return 😈) x;"
  , "return\n😈) x;"
  , "return 😈)\nx;"
  , "return )😈 x;"
  , "return\n)😈 x;"
  , "return )😈\nx;"
  , "break"
  , "break x"
  , "break\nx"
  , "break;"
  , "break;x"
  , "break x;"
  , "loop {}"
  , "loop { let x = y; }"
  , "!x"
  , "+x"
  , "-x"
  , "!x.p"
  , "!x()"
  , "!"
  , "!😈x"
  , "!)x"
  , "!😈)x"
  , "!)😈x"
  , "!!x"
  , "++x"
  , "--x"
  , "+-x"
  , "-+x"
  , "a + b"
  , "a + b + c"
  , "a - b"
  , "a - b - c"
  , "a * b"
  , "a * b * c"
  , "a / b"
  , "a / b / c"
  , "a % b"
  , "a % b % c"
  , "a == b"
  , "a == b == c"
  , "a != b"
  , "a != b != c"
  , "a < b"
  , "a < b < c"
  , "a <= b"
  , "a <= b <= c"
  , "a > b"
  , "a > b > c"
  , "a >= b"
  , "a >= b >= c"
  , "a + b - c"
  , "a - b + c"
  , "a + b * c"
  , "a * b + c"
  , "a + b / c"
  , "a / b + c"
  , "a * b / c"
  , "a / b * c"
  , "a + b * c + d"
  , "a * b + c * d"
  , "a ^ b + c"
  , "a + b ^ c"
  , "a ^ b * c"
  , "a * b ^ c"
  , "a > b + c"
  , "a + b > c"
  , "a < b + c"
  , "a + b < c"
  , "a >= b + c"
  , "a + b >= c"
  , "a <= b + c"
  , "a + b <= c"
  , "a + b == c"
  , "a == b + c"
  , "a + b != c"
  , "a != b + c"
  , "a =="
  , "== b"
  , "a 😈 == b"
  , "a == 😈 b"
  , "a == b 😈"
  , "a ) == b"
  , "a == ) b"
  , "a.p + b.q"
  , "!a + !b"
  , "a() + b()"
  , "a + b +"
  , "a + b + c +"
  , "a 😈 + b + c"
  , "a + 😈 b + c"
  , "a + b 😈 + c"
  , "a + b + 😈 c"
  , "a + b + c 😈"
  , "^ b * c ^ d"
  , "a ^ * c ^ d"
  , "a ^ b * ^ d"
  , "a * ^ c * d"
  , "a * b ^ * d"
  , "a ^ b * c ^"
  , "a 😈 * b + c * d"
  , "a * 😈 b + c * d"
  , "a * b 😈 + c * d"
  , "a * b + 😈 c * d"
  , "a * b + c 😈 * d"
  , "a * b + c * 😈 d"
  , "a * b + c * d 😈"
  , "a - b + c"
  , "a + -b + c"
  , "if x {} else if y {}"
  , "if x {} else if y {} else {}"
  , "if x {} else if y {} else if z {}"
  , "if x {} else if y {} else if z {} else {}"
  , "if x {} else if {}"
  , "if x {} else 😈 if y {}"
  , "if x {} else 😈 if y + z {}"
  , "if x {} else { if y {} }"
  , "a + b * c ^ d"
  , "a * ^ b"
  , "a ^ * b"
  , "a * * b"
  , "a 😈 * ^ b"
  , "a 😈 ^ * b"
  , "a 😈 * * b"
  , "{}"
  , "{p: a}"
  , "{p: a, q: b}"
  , "{,}"
  , "{p: a,}"
  , "{p: a, q: b,}"
  , "{p: a q: b}"
  , "{p: a,, q: b}"
  , "{p: a, q: b,,}"
  , "{p: a q: b,}"
  , "{| o}"
  , "{p: a | o}"
  , "{p: a, | o}"
  , "{p: a, q: b | o}"
  , "{p: a | {q: b}}"
  , "{p: a | {q: b | {}}}"
  , "{p: a | {q: b | o}}"
  , "{: a}"
  , "{p a}"
  , "{p: }"
  , "{: a, q: b}"
  , "{p a, q: b}"
  , "{p: , q: b}"
  , "{p}"
  , "{p, q}"
  , "{p: a, q}"
  , "{p, q: b}"
  , "if {} {}"
  , "if {p: a}.p {}"
  , "{p: a}.p"
  , "{😈 p: a}"
  , "{p 😈 : a}"
  , "{p: 😈 a}"
  , "{p: a 😈}"
  , "{😈}"
  , "a && b"
  , "a && b && c"
  , "a || b || c"
  , "a && b || c"
  , "a || b && c"
  , "a && b && c && d"
  , "a || b && c && d"
  , "a && b || c && d"
  , "a && b && c || d"
  , "a && b || c || d"
  , "a || b && c || d"
  , "a || b || c && d"
  , "a || b || c || d"
  , "let true = x"
  , "let {} = o"
  , "let {a} = o"
  , "let {a, b} = o"
  , "let {a, b, c} = o"
  , "let {,} = o"
  , "let {a,} = o"
  , "let {a, b,} = o"
  , "let {a, b, c,} = o"
  , "let {a: a2} = o"
  , "let {a: a2, b: b2} = o"
  , "let {a: a2, b: b2, c: c2} = o"
  , "let {a: a2, b} = o"
  , "let {a, b: b2} = o"
  , "let {| o} = o"
  , "let {a | o} = o"
  , "let {a, | o} = o"
  , "let {a, b | o} = o"
  , "let {a, b, c | o} = o"
  , "let {a | {b | o}} = o"
  , "let {a | {b | {c | o}}} = o"
  , "let {a | {b | {c | {}}}} = o"
  , "{a: {b: c}}"
  , "{a {}}"
  , "{a true}"
  , "let x: T = y;"
  , "let x: = y;"
  , "let x T = y;"
  , "(x: T)"
  , "(x:)"
  , "(x T)"
  , "fun f g() {}"
  , "fun f(a: T) {}"
  , "fun f(a: T, b: U) {}"
  , "fun f(a, b: U) {}"
  , "fun f(a: T, b) {}"
  , "fun f(a: T, b: U, c: V) {}"
  , "let f = fun(a: T) {};"
  , "let f = fun(a: T, b: U) {};"
  , "let f = fun(a, b: U) {};"
  , "let f = fun(a: T, b) {};"
  , "let f = fun(a: T, b: U, c: V) {};"
  , "fun f() -> T {}"
  , "fun f() -> {}"
  , "fun f() T {}"
  , "fun f() -> {} {}"
  , "(x: !)"
  , "(x: <> X)"
  , "(x: <T> X)"
  , "(x: <T: A> X)"
  , "(x: <T = A> X)"
  , "(x: <T, U> X)"
  , "(x: <T: A, U: B> X)"
  , "(x: <T = A, U = B> X)"
  , "(x: <T = A, U: B> X)"
  , "(x: <T: A, U = B> X)"
  , "(x: <T, U: B> X)"
  , "(x: <T: A, U> X)"
  , "(x: <T, U = B> X)"
  , "(x: <T = A, U> X)"
  , "(x: <,> X)"
  , "(x: <T,> X)"
  , "(x: <T, U,> X)"
  , "fun f<>() {}"
  , "fun f<T>() {}"
  , "fun f<T: A>() {}"
  , "fun f<T = A>() {}"
  , "fun f<T, U>() {}"
  , "fun f<T: A, U: B>() {}"
  , "fun f<T = A, U = B>() {}"
  , "fun f<T = A, U: B>() {}"
  , "fun f<T: A, U = B>() {}"
  , "fun f<T, U: B>() {}"
  , "fun f<T: A, U>() {}"
  , "fun f<T, U = B>() {}"
  , "fun f<T = A, U>() {}"
  , "fun f<,>() {}"
  , "fun f<T,>() {}"
  , "fun f<T, U,>() {}"
  , "(x: {})"
  , "(x: {a: T})"
  , "(x: {a: T, b: U})"
  , "(x: {,})"
  , "(x: {a: T,})"
  , "(x: {a: T, b: U,})"
  , "(x: {a})"
  , "(x: {a, b})"
  , "(x: {a: T, b})"
  , "(x: {a, b: U})"
  , "(x: {| O})"
  , "(x: {a: T | O})"
  , "(x: {a: T, | O})"
  , "(x: {a: T, b: U | O})"
  , "(x: {a: T, b: U, | O})"
  , "(x: {a: T | {b: U | O}})"
  , "(x: {a: T | {b: U | {}}})"
  , "x\n.Foo"
  , "x;\n.Foo;"
  , "(x: fun)"
  , "(x: fun😈)"
  , "(x: fun())"
  , "(x: fun() ->)"
  , "(x: fun() -> A)"
  , "(x: fun(A) -> B)"
  , "(x: fun(A, B) -> C)"
  , "(x: fun(A, B, C) -> D)"
  , "(x: fun(,) -> A)"
  , "(x: fun(A,) -> B)"
  , "(x: fun(A, B,) -> C)"
  , "(x: fun(A, B, C,) -> D)"
  , "(x: fun<>() -> A)"
  , "(x: fun<A>() -> B)"
  , "(x: fun<A, B>() -> C)"
  , "(x: fun<A, B, C>() -> D)"
  , "(x: fun<,>() -> A)"
  , "(x: fun<A,>() -> B)"
  , "(x: fun<A, B,>() -> C)"
  , "(x: fun<A, B, C,>() -> D)"
  , "(x: fun<A, B>(C, D) -> E)"
  , "(x: <A, B> fun<C, D>(E, F) -> G)"
  , "let (x) = y;"
  , "(x: (T));"
  , "(x: <A> (<B> T));"
  , "(x: <A> <B> T);"
  , "/*"
  , "/*/"
  , "/**/"
  , "/* *"
  , "/* **"
  , "/* * /"
  , "/* */"
  , "/* **/"
  , "/* x"
  , "/*/ x"
  , "/**/ x"
  , "/* * x"
  , "/* ** x"
  , "/* * / x"
  , "/* */ x"
  , "/* **/ x"
  , "a + b + c + (d * e)"
  , "f(do{😈;})"
  , "f("
  , "f(a"
  , "f(a,"
  , "f(a, b"
  , "f(a, b,"
  , "{"
  , "{|o"
  , "{a: b"
  , "{a"
  , "{a: b,"
  , "{a,"
  , "let {"
  , "let {|o"
  , "let {a: b"
  , "let {a"
  , "let {a: b,"
  , "let {a,"
  , "let a = b; 😈 let c = d;"
  , "let x = void;"
  , "let void = x;"
  , "let void = void;"
  , "let x: void = void;"
  , "let void: x = void;"
  , "let void: void = x;"
  , "let void: void = void;"
  , "let Void: Void = Void;"
  , "(if foo)"
  , "(if foo {} else)"
  , "(do)"
  , "(loop)"
  , "(fun"
  , "(fun<>"
  , "(fun<T>"
  , "(fun()"
  , "(fun() -> T"
  , "fun foo"
  , "fun foo<>"
  , "fun foo<T>"
  , "fun foo()"
  , "fun foo() -> T"
  , "fun"
  , "fun<>"
  , "fun<T>"
  , "fun()"
  , "fun() -> T"
  , "0"
  , "1"
  , "3.1415"
  , "1e2"
  , "1e+2"
  , "1e-2"
  , "0b101"
  , "0xC055EE"
  , "let 0 = x"
  , "let 1 = x"
  , "let 3.1415 = x"
  , "let 1e2 = x"
  , "let 1e+2 = x"
  , "let 1e-2 = x"
  , "let 0b101 = x"
  , "let 0xC055EE = x"
  , "0a"
  , "let x = 0a"
  , "let 0a = x"
  , "do { let id = fun(x) { x }; fun(x) { x } }"
  , "fun(x) { x }"
  , "fun 😈(x) { x }"
  ]

openSnapshotFile :: IO Handle
openSnapshotFile = do
  h <- openFile "test/Brite/Syntax/ParserSpecSnapshot.md" WriteMode
  hPutStrLn h "# ParserSpecSnapshot"
  return h

closeSnapshotFile :: Handle -> IO ()
closeSnapshotFile h = do
  hPutStrLn h ""
  hPutStrLn h (replicate 80 '-')
  hClose h

spec :: Spec
spec = beforeAll openSnapshotFile $ afterAll closeSnapshotFile $ do
  flip mapM_ testData $ \source ->
    it (Text.unpack (escape source)) $ \h ->
      let
        (module_, diagnostics) = runDiagnosticWriter (parseModule (tokenize source))
        moduleDebug = Text.Lazy.toStrict (Text.Builder.toLazyText (AST.debugModule (AST.convertModule module_)))
        rebuiltSource = Text.Lazy.toStrict (Text.Builder.toLazyText (CST.moduleSource module_))
      in seq moduleDebug $ do
        hPutStrLn h ""
        hPutStrLn h (replicate 80 '-')
        hPutStrLn h ""
        hPutStrLn h "### Source"
        hPutStrLn h "```ite"
        hPutStrLn h (Text.unpack source)
        hPutStrLn h "```"
        hPutStrLn h ""
        hPutStrLn h "### AST"
        hPutStrLn h "```"
        hPutStr h (Text.unpack moduleDebug)
        hPutStrLn h "```"
        if Seq.null diagnostics then return () else (do
          hPutStrLn h ""
          hPutStrLn h "### Errors"
          flip mapM_ diagnostics (\diagnostic ->
            hPutStrLn h (Text.Lazy.unpack (Text.Builder.toLazyText
              (Text.Builder.fromText "- " <> debugDiagnostic diagnostic)))))
        rebuiltSource `shouldBe` source

escape :: Text -> Text
escape = Text.concatMap
  (\c ->
    case c of
      '\n' -> "\\n"
      '\r' -> "\\r"
      _ -> Text.singleton c)
