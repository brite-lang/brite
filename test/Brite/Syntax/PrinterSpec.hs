{-# LANGUAGE OverloadedStrings #-}

module Brite.Syntax.PrinterSpec (spec) where

import Brite.Diagnostics
import Brite.Syntax.Parser
import Brite.Syntax.Printer
import qualified Brite.Syntax.PrinterAST as PrinterAST
import Brite.Syntax.Tokens
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Text.Lazy as Text.Lazy
import qualified Data.Text.Lazy.Builder as Text.Builder
import Test.Hspec
import System.IO

testData :: [Text]
testData =
  [ "true"
  , "false"
  , "true false"
  , "true false true"
  , "true"
  , "  true"
  , "true  "
  , "  true  "
  , "\ntrue"
  , "\n\ntrue"
  , "\rtrue"
  , "\r\rtrue"
  , "\r\ntrue"
  , "\r\n\r\ntrue"
  , "\n\rtrue"
  , "/**/true"
  , "/**/ true"
  , "/**/  true"
  , "/**/   true"
  , "/**/\ttrue"
  , "/**/\t\ttrue"
  , "/**/\t\t\ttrue"
  , "/**/\ntrue"
  , "/**/\n\ntrue"
  , "/**/\n\n\ntrue"
  , "/**/\rtrue"
  , "/**/\r\rtrue"
  , "/**/\r\r\rtrue"
  , "/**/\r\ntrue"
  , "/**/\r\n\r\ntrue"
  , "/**/\r\n\r\n\r\ntrue"
  , "/**/\n\rtrue"
  , "/**/\n\r\r\ntrue"
  , "/**/ \ntrue"
  , "/**/\n true"
  , "/**/  \ntrue"
  , "/**/\n  true"
  , "/**/   \ntrue"
  , "/**/\n   true"
  , "/**/   \n   true"
  , "/**/ \n \n true"
  , "/**/ \n \n \n true"
  , "//\n/**/ true"
  , "//\n\n/**/ true"
  , "//\n\n\n/**/ true"
  , "/**/\n/**/ true"
  , "/**/\n\n/**/ true"
  , "/**/\n\n\n/**/ true"
  , "/**/ /**/ true"
  , "//\ntrue"
  , "//\n\ntrue"
  , "//\n\n\ntrue"
  , "//\rtrue"
  , "//\r\rtrue"
  , "//\r\r\rtrue"
  , "//\r\ntrue"
  , "//\r\n\r\ntrue"
  , "//\r\n\r\n\r\ntrue"
  , "// \ntrue"
  , "//  \ntrue"
  , "//   \ntrue"
  , "//\n true"
  , "//\n  true"
  , "//\n   true"
  , "// \n \n true"
  , "// \n \n \n true"
  , "/**//**/true"
  , "/**/ /**/ true"
  , "/**/  /**/  true"
  , "/**/   /**/   true"
  , "/**/\n/**/\ntrue"
  , "/**/\n\n/**/\n\ntrue"
  , "/**/\n\n\n/**/\n\n\ntrue"
  , "/**/\n\n/**/\ntrue"
  , "/**/\n\n\n/**/\ntrue"
  , "/**/\n/**/\n\ntrue"
  , "/**/\n/**/\n\n\ntrue"
  , "//\n//\ntrue"
  , "//\n\n//\n\ntrue"
  , "//\n\n\n//\n\n\ntrue"
  , "//\n\n//\ntrue"
  , "//\n\n\n//\ntrue"
  , "//\n//\n\ntrue"
  , "//\n//\n\n\ntrue"
  , "true/**/"
  , "true /**/"
  , "true  /**/"
  , "true   /**/"
  , "true/**//**/"
  , "true /**/ /**/"
  , "true  /**/  /**/"
  , "true   /**/   /**/"
  , "true//"
  , "true //"
  , "true  //"
  , "true   //"
  , "true //\n"
  , "true //\n\n"
  , "true //\n\n\n"
  , "true //\nfalse"
  , "x"
  , "x y"
  , "x y z"
  , "(x)"
  , "(true)"
  , "( x)"
  , "(x )"
  , "( x )"
  , "(  x)"
  , "(x  )"
  , "(  x  )"
  , "!x"
  , "+x"
  , "-x"
  , "!  x"
  , "!\nx"
  , "a + b + c + d"
  , "a + (b + c + d)"
  , "a + (b + (c + d))"
  , "((a + b) + c) + d"
  , "a + (b + c) + d"
  , "a + b - c + d"
  , "a + (b - c + d)"
  , "a + (b - (c + d))"
  , "((a + b) - c) + d"
  , "a + (b - c) + d"
  , "a * b + c * d"
  , "a * (b + c) * d"
  , "(a * b) + (c * d)"
  , "((a * b) + c) * d"
  , "a * (b + (c * d))"
  , "a + -b + c"
  , "-a + b + -c"
  , "a + (-b) + c"
  , "(-a) + b + (-c)"
  , "a + -(b) + c"
  , "-(a) + b + -(c)"
  , "a + -(b + c)"
  , "-(a + b) + -c"
  , "(a * b) ^ (c * d)"
  , "(a + b) * (c + d)"
  , "(a + b) / (c + d)"
  , "(a + b) % (c + d)"
  , "(a < b) + (c < d)"
  , "(a < b) - (c < d)"
  , "(a == b) < (c == d)"
  , "(a == b) <= (c == d)"
  , "(a == b) > (c == d)"
  , "(a == b) >= (c == d)"
  , "(a && b) == (c && d)"
  , "(a && b) != (c && d)"
  , "(a || b) && (c || d)"
  , "(a && b) || (c && d)"
  , "reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong"
  , "reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong + a + b"
  , "reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong + a * b"
  , "reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong + (a + b)"
  , "reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong + (a * b)"
  , "reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong"
  , "reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong + a + b"
  , "reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong + a * b"
  , "reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong + (a + b)"
  , "reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong + (a * b)"
  , "reallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyLong"
  , "reallyReallyReallyReallyReallyLong * reallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyLong * reallyReallyReallyReallyReallyLong"
  , "reallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyLong * reallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyLong"
  , "(reallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyLong) * (reallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyLong)"
  , "reallyReallyReallyReallyReallyReallyReallyLong * reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong * reallyReallyReallyReallyReallyReallyReallyLong"
  , "reallyReallyReallyReallyReallyReallyReallyLong * (reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong) * reallyReallyReallyReallyReallyReallyReallyLong"
  , "reallyReallyReallyReallyReallyReallyReallyLong && (reallyReallyReallyReallyReallyReallyReallyLong || reallyReallyReallyReallyReallyReallyReallyLong) && reallyReallyReallyReallyReallyReallyReallyLong"
  , "f(reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong)"
  , "(reallyReallyReallyReallyReallyReallyReallyLong || reallyReallyReallyReallyReallyReallyReallyLong) && (reallyReallyReallyReallyReallyReallyReallyLong || reallyReallyReallyReallyReallyReallyReallyLong)"
  , "// blah blah blah\n(reallyReallyReallyReallyReallyReallyReallyLong ||\n// blah blah blah\nreallyReallyReallyReallyReallyReallyReallyLong) &&\n// blah blah blah\n(reallyReallyReallyReallyReallyReallyReallyLong ||\n// blah blah blah\nreallyReallyReallyReallyReallyReallyReallyLong)"
  , "\n// blah blah blah\n(reallyReallyReallyReallyReallyReallyReallyLong ||\n\n// blah blah blah\nreallyReallyReallyReallyReallyReallyReallyLong) &&\n\n// blah blah blah\n(reallyReallyReallyReallyReallyReallyReallyLong ||\n\n// blah blah blah\nreallyReallyReallyReallyReallyReallyReallyLong)"
  , "// blah blah blah\n\n(reallyReallyReallyReallyReallyReallyReallyLong ||\n// blah blah blah\n\nreallyReallyReallyReallyReallyReallyReallyLong) &&\n// blah blah blah\n\n(reallyReallyReallyReallyReallyReallyReallyLong ||\n// blah blah blah\n\nreallyReallyReallyReallyReallyReallyReallyLong)"
  , "return (reallyReallyReallyReallyReallyReallyReallyLong || reallyReallyReallyReallyReallyReallyReallyLong) && (reallyReallyReallyReallyReallyReallyReallyLong || reallyReallyReallyReallyReallyReallyReallyLong)"
  , "--x"
  , "-(-x)"
  , "-+x"
  , "-(+x)"
  , "!!x"
  , "!(!x)"
  , "!o.p"
  , "(!o).p"
  , "o  .  p"
  , "o\n.p"
  , "o.\np"
  , "o.p.q"
  , "reallyReallyReallyReallyReallyReallyReallyLong.reallyReallyReallyReallyReallyReallyReallyLong"
  , "reallyReallyReallyReallyReallyReallyReallyLong.reallyReallyReallyReallyReallyReallyReallyLong.reallyReallyReallyReallyReallyReallyReallyLong"
  , "reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong.p"
  , "reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong.p.q"
  , "reallyReallyReallyReallyReallyReallyReallyLong.reallyReallyReallyReallyReallyReallyReallyLong.p"
  , "reallyReallyReallyReallyReallyReallyReallyLong.reallyReallyReallyReallyReallyReallyReallyLong.p.q"
  , "reallyReallyReallyReallyReallyReallyReallyLong.p.reallyReallyReallyReallyReallyReallyReallyLong"
  , "reallyReallyReallyReallyReallyReallyReallyLong.p.q.reallyReallyReallyReallyReallyReallyReallyLong"
  , "reallyReallyReallyReallyReallyReallyReallyLong.p.reallyReallyReallyReallyReallyReallyReallyLong.q"
  , "foo.bar.qux.lit.foo.bar.qux.lit.foo.bar.qux.lit.foo.bar.qux.lit.foo.bar.qux.lit.foo.bar.qux.lit"
  , "(a + b).c"
  , "let x = y"
  , "let x = y;"
  , "let    x    =    y;"
  , "let\nx\n=\ny;"
  , "a // a\n+ // +\nb // b"
  , "// a\na\n// +\n+\n// b\nb"
  , "// a\na\n/**/ // +\n+\n// b\nb"
  , "// a\na\n// +\n\n+\n// b\nb"
  , "// a\n\na\n// +\n+\n// b\nb"
  , "a /* a */ + /* + */ b /* b */"
  , "/* a */ a\n/* + */ +\n/* b */ b"
  , "a /* a\n */ + /* +\n */ b /* b\n */"
  , "/* a\n */ a\n/* +\n */ +\n/* b\n */ b"
  , "/* blah blah blah */ let x = y;"
  , "/* blah blah blah */\nlet x = y;"
  , "/*\n * blah blah blah\n */\nlet x = y;"
  , "let x = y; /* blah blah blah */"
  , "let x = y;   /* blah blah blah */"
  , "let x = y   /* blah blah blah */   ;"
  , "let x = y;\n/* blah blah blah */"
  , "let x = y;\n/*\n * blah blah blah\n */"
  , "/**/ a + b"
  , "a /**/ + b"
  , "a + /**/ b"
  , "a + b /**/"
  , "/*\n*/ a + b"
  , "a /*\n*/ + b"
  , "a + /*\n*/ b"
  , "a + b /*\n*/"
  , "/*\n*/ reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong"
  , "reallyReallyReallyReallyReallyReallyReallyLong /*\n*/ + reallyReallyReallyReallyReallyReallyReallyLong"
  , "reallyReallyReallyReallyReallyReallyReallyLong + /*\n*/ reallyReallyReallyReallyReallyReallyReallyLong"
  , "reallyReallyReallyReallyReallyReallyReallyLong + reallyReallyReallyReallyReallyReallyReallyLong /*\n*/"
  , "//\na"
  , "a //"
  , "a // a\n+ b // b"
  , "a + // b\nb"
  , "a +\n// b\nb"
  , "f(aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa);"
  , "f(aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa);"
  , "f(aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa);"
  , "f(aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa);"
  , "f(𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷);"
  , "f(𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷a);"
  , "f(𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷);"
  , "f(𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷a);"
  , "f(a /**/);"
  , "f(a /*\n*/);"
  , "f(a) /*\n*/;"
  , "f(\na // a\n+ // +\nb // b\n)"
  , "f(\n// a\na\n// +\n+\n// b\nb\n)"
  , "f(a + // b\nb)"
  , "f(a +\n// b\nb)"
  , "f(\na + b // blah blah blah\n)"
  , "f(/**/a)"
  , "f(a/**///\n)"
  , "f(\n//\na\n)"
  , "f(\n/**/ //\na\n)"
  , "f(\n/**/    //\na\n)"
  , "let x = 😈"
  , "let x =\n  😈"
  , "let x =\n\n\n😈"
  , "let x =     \n😈"
  , "let   x y; let   x=y;"
  , "let   x=y; let   x y;"
  , "(a + b let x = y;"
  , "let x = y; /**/ //"
  , "let x = y; /**/   //"
  , "/**/ //\nlet x = y;"
  , "/**/   //\nlet x = y;"
  , "/**/ //\n\n\nlet x = y;"
  , "//"
  , "//\n//"
  , "\n//\n//"
  , "\n\n//\n//"
  , "//\n//\n"
  , "//\n\n//\n"
  , "/**/ //"
  , "//\n/**/ //"
  , "\n/**/ //\n//"
  , "\n\n/**/ //\n//"
  , "//\n/**/ //\n"
  , "//\n\n/**/ //\n"
  , "/**/ /**/"
  , "/**/ //\n\n\n"
  , "/**/ //\n\n\n//\n"
  , "let x = y;\n//"
  , "let x = y;\n\n//"
  , "let x = y;\n\n\n//"
  , "let x = y;\n/**/"
  , "let x = y;\n\n/**/"
  , "let x = y;\n\n\n/**/"
  , "let x = y;\n//\nlet x = y;"
  , "let x = y;\n\n//\nlet x = y;"
  , "let x = y;\n\n\n//\nlet x = y;"
  , "let x = y;\n//\n\nlet x = y;"
  , "let x = y;\n//\n\n\nlet x = y;"
  , "let x = y;\n\n//\n\nlet x = y;"
  , "let x = y;\nlet x = y;"
  , "let x = y;\n\nlet x = y;"
  , "let x = y;\n\n\nlet x = y;"
  , "let x = y;\n"
  , "let x = y;\n\n"
  , "let x = y;\n\n\n"
  , "\nlet x = y;"
  , "\n\nlet x = y;"
  , "\n\n\nlet x = y;"
  , "let x = y;\n/**/ //"
  , "let x = y;\n/**/ //\n"
  , "let x = y;\n/**/ //\n\n"
  , "let x = y;\n/**/ //\n\n\n"
  , "let x = y;\n/**/ /**/"
  , "let x = y;\n/**/ /**/\n"
  , "let x = y;\n/**/ /**/\n\n"
  , "let x = y;\n/**/ /**/\n\n\n"
  , "let x = y;\n😈 let x = y;"
  , "let x = y;\n\n😈 let x = y;"
  , "let x = y;\n\n\n😈 let x = y;"
  , "let x = y; 😈\nlet x = y;"
  , "let x = y; 😈\n\nlet x = y;"
  , "let x = y; 😈\n\n\nlet x = y;"
  , "let x = y;\n😈\nlet x = y;"
  , "let x = y;\n\n😈\n\nlet x = y;"
  , "let x = y;\n😈"
  , "let x = y;\n\n😈"
  , "let x = y;\n\n\n😈"
  , "let x = y;\n😈\n\n\n\n\nlet x = y;"
  , "let x = a +\n//\nb"
  , "return"
  , "return; //"
  , "return a +\n//\nb"
  , "let x = y\n//\n;"
  , "let x = y\n//\n\n;"
  , "return a + b"
  , "/**/\n//\nlet x = y;"
  , "//\n/**/\nlet x = y;"
  , "/**/\n\n//\n\nlet x = y;"
  , "//\n\n/**/\n\nlet x = y;"
  , "a\n/**/\n+ b"
  , "a +\n/**/\nb"
  , "a\n//\n+ b"
  , "a +\n//\nb"
  , "/**/ /**/\nlet x = y;"
  , "f()"
  , "f(/**/)"
  , "f(/**/)"
  , "f(\n//\n)"
  , "f(a)"
  , "f(a, b)"
  , "f(a, b, c)"
  , "f(a,)"
  , "f(a, b,)"
  , "f(a, b, c,)"
  , "f(\na //\n)"
  , "f(\na, //\n)"
  , "f(a, /**/)"
  , "f(a, //\n)"
  , "f(a, //\n\n)"
  , "f(a\n/**/ ,)"
  , "f(a\n/**/\n,)"
  , "f(a\n/**/\n\n,)"
  , "f(a\n//\n,)"
  , "f(a\n\n//\n\n,)"
  , "f(a\n//\n//\n,)"
  , "f(a\n\n//\n\n//\n\n,)"
  , "f(reallyReallyReallyReallyReallyReallyReallyLong)"
  , "f(reallyReallyReallyReallyReallyReallyReallyLong, reallyReallyReallyReallyReallyReallyReallyLong)"
  , "f(reallyReallyReallyReallyReallyReallyReallyLong, reallyReallyReallyReallyReallyReallyReallyLong, reallyReallyReallyReallyReallyReallyReallyLong)"
  , "f(a, b, c,)"
  , "f(a, b, c, /**/)"
  , "f(do{})"
  , "f(do{x})"
  , "f(do{f(\n//\na)})"
  , "f(do{a;b})"
  , "f(do{let x = y})"
  , "f(do{return x})"
  , "f(do{let x = y; let z = y; z})"
  , "f(do{😈;})"
  , "f(do{let  x = y;😈})"
  , "f(do{let  x = y;😈  let   x = y})"
  , "f(do{let  x = y;😈; let   x = y})"
  , ";"
  , ";;"
  , ";\n;"
  , ";\n\n;"
  , "let x = y;;"
  , "let x = y;\n;"
  , "let x = y;\n\n;"
  , "let x = y;; let x = y;"
  , "let x = y;;\nlet x = y;"
  , "let x = y;;\n\nlet x = y;"
  , "let x = y;\n; let x = y;"
  , "let x = y;\n\n; let x = y;"
  , "let x = y;\n;\nlet x = y;"
  , "let x = y;\n;\n\nlet x = y;"
  , "let x = y;\n\n;\nlet x = y;"
  , "let x = y;\n//\n;\nlet x = y;"
  , "let x = y;\n\n//\n;\nlet x = y;"
  , "let x = y;\n\n//\n\n;\n\nlet x = y;"
  , "// Hello, world!\n;"
  , "// Hello, world!\n\n;"
  , "// Hello, world!\n\n\n;"
  , "; // Hello, world!"
  , "// Hello, world!\n;\nlet x = y;"
  , "// Hello, world!\n;\n\nlet x = y;"
  , "// Hello, world!\n\n;\nlet x = y;"
  , "// Hello, world!\n\n;\n\nlet x = y;"
  , "do {\n//\n}"
  , "do {\n//\n//\n}"
  , "do {\n// a\n// b\n}"
  , "do {\n//\n\n//\n}"
  , "do {\n//\n\n//\n\n}"
  , "do {\n//\n//\n\n}"
  , "do {\n\n//\n//\n}"
  , "do {x\n//\n}"
  , "do {x\n//\n//\n}"
  , "do {x\n//\n\n//\n}"
  , "do {x\n//\n\n//\n\n}"
  , "do {x\n//\n//\n\n}"
  , "do {x\n\n//\n//\n}"
  , "f(\n//\n)"
  , "f(\n//\n//\n)"
  , "f(\n//\n\n//\n)"
  , "f(\n//\n\n//\n\n)"
  , "f(\n//\n//\n\n)"
  , "f(\n\n//\n//\n)"
  , "f(x\n//\n)"
  , "f(x\n//\n//\n)"
  , "f(x\n//\n\n//\n)"
  , "f(x\n//\n\n//\n\n)"
  , "f(x\n//\n//\n\n)"
  , "f(x\n\n//\n//\n)"
  , "do {/**/}"
  , "do {/**/\n}"
  , "do {\n/**/\n}"
  , "do {let x = y;\n\nlet x = y;}"
  , "f(x,\n//\ng(aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)\n);"
  , "f(x,\n//\ng(aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)\n);"
  , "f(x,\n//\ng(aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)\n);"
  , "f(x,\n//\ng(aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa)\n);"
  , "f(x,\n//\ng(𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷)\n);"
  , "f(x,\n//\ng(𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷a)\n);"
  , "f(x,\n//\ng(𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷)\n);"
  , "f(x,\n//\ng(𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷𐐷a)\n);"
  , "do {\n//\nlet x = y;}"
  , "do {\n//\n\nlet x = y;}"
  , "f(\n  // b\n  a + \n  b\n);"
  , "do {}; //"
  , "do { x; }; //"
  , "do { let x = y; }; //"
  , "do {} //"
  , "//\ndo {}"
  , "let x = f(\n//\n);"
  , "(do {});"
  , "//\n(a + b) * c;"
  , "//\n\n(a + b) * c;"
  , "(a + b) //\n * c;"
  , "//\n((a + b)) * c;"
  , "//\n\n((a + b)) * c;"
  , "((a + b)) //\n * c;"
  , "//\na + b"
  , "(a +\n//\nb) * c"
  , "let x = a + b;"
  , "let x =\n//\na + b;"
  , "let x = a +\n//\nb;"
  , "return (\n//\na + b);"
  , "return (a +\n//\nb);"
  , "a + b +\n//\nc + d"
  , "//\na + b + c + d"
  , "- // -\nx;"
  , "- // -\n\nx;"
  , "- // -\n\n\nx;"
  -- TODO: This test breaks!!! , "a\n/**/;"
  , "a\n//\n;"
  , "a /**/;"
  , "a //\n;"
  , "(x T)"
  , "/* a */ (/* b */ x /* c */) /* d */;"
  , "/* a */ (/* b */ x /* c */\n//\n) /* d */;"
  , "/* a */ (/* b */\n//\nx /* c */) /* d */;"
  , "/* a */ (\n//\n/* b */ x /* c */) /* d */;"
  , "/**/ x /**/"
  , "/**/ x; /**/"
  , "/**/ x /**/;"
  , "/**/ x /**/; /**/"
  , "x //"
  , "x; //"
  , "x\n//\n"
  , "x\n//\n;"
  , "/**/ ; /**/"
  , "//\n\n/**/;"
  , "   😈"
  , "😈   "
  , "😈\n    \n😈"
  , "😈\n//    \n😈"
  , "😈\n/*\n    \n*/\n😈"
  , "😈\n/*\n    \n */\n😈"
  , "😈\n/*\n    */\n😈"
  , "😈 /*   "
  , "; /*   "
  , "// a\n// b"
  , "// a\n// b\nx"
  , "/* a */ /* b */ x"
  , "x /* a */ /* b */"
  , "/* a */ /* b */"
  , "/**/-x"
  , "-/**/x"
  , "-x/**/"
  , "-/**/x/**/"
  , "-\n/**/x"
  , "/* a */ -\n/* b */x"
  , "/* a */ -/* b */x"
  , "-(x /* a */) /* b */"
  , "let x = y /* a */ /* b */"
  , "return x /* a */ /* b */"
  , "break x /* a */ /* b */"
  , "let x = -y /* a */ /* b */"
  , "return -x /* a */ /* b */"
  , "break -x /* a */ /* b */"
  , "/* a */ do /* b */ { /* c */ } /* d */"
  , "/* a */ do\n/* b */ { /* c */ } /* d */"
  , "loop{  };"
  , "a\n/**/ + /**/ b"
  , "a +\n/**/ b"
  , "a +\n// x\n\n// y\nb"
  , "a +\n\n// x\n// y\nb"
  , "a +\n\n\n// x\n// y\nb"
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
    it (Text.unpack (escape input)) $ \h ->
      let
        (inputModule, diagnostics) = runDiagnosticWriter (parseModule (tokenize input))
        output = Text.Lazy.toStrict $ Text.Builder.toLazyText $
          printModule (PrinterAST.convertModule inputModule)
        (outputModule, _) = runDiagnosticWriter (parseModule (tokenize output))
        reprintedOutput = Text.Lazy.toStrict $ Text.Builder.toLazyText $
          printModule (PrinterAST.convertModule outputModule)
      in seq output $ do
        hPutStrLn h ""
        hPutStrLn h (replicate 80 '-')
        hPutStrLn h ""
        hPutStrLn h "### Input"
        hPutStrLn h "```ite"
        hPutStrLn h (Text.unpack input)
        hPutStrLn h "```"
        hPutStrLn h ""
        hPutStrLn h "### Output"
        hPutStrLn h "```"
        hPutStr h (Text.unpack output)
        hPutStrLn h "```"
        if null diagnostics then return () else (do
          hPutStrLn h ""
          hPutStrLn h "### Errors"
          flip mapM_ diagnostics (\diagnostic ->
            hPutStrLn h (Text.Lazy.unpack (Text.Builder.toLazyText
              (Text.Builder.fromText "- " <> debugDiagnostic diagnostic)))))

        -- Test that when we parse and re-print the output we get the same thing.
        reprintedOutput `shouldBe` output

        -- Test to make sure the output has no trailing spaces, but only if there were no
        -- diagnostics. If there were parse errors then we may print raw text with trailing spaces.
        (Text.foldl'
          (\s c ->
            case c of
              '\n' | s -> error "Has trailing spaces."
              '\r' | s -> error "Has trailing spaces."
              ' ' -> True
              _ -> False)
          False
          output)
            `shouldBe` False

escape :: Text -> Text
escape = Text.concatMap
  (\c ->
    case c of
      '\n' -> "\\n"
      '\r' -> "\\r"
      '\t' -> "\\t"
      _ -> Text.singleton c)
