import {Err, Ok, Result, ResultType} from '../Utils/Result';

import {
  AliasPattern,
  BindingName,
  BindingPattern,
  CallExpression,
  ConditionalExpression,
  DeconstructPattern,
  FunctionExpression,
  FunctionParameter,
  FunctionType,
  GenericType,
  HoleExpression,
  HolePattern,
  ListExpression,
  ListPattern,
  MatchCase,
  MatchExpression,
  MemberExpression,
  MemberType,
  Name,
  Pattern,
  PatternExpression,
  QualifiedPattern,
  QuantifiedType,
  RecordExpression,
  RecordExpressionProperty,
  RecordPattern,
  RecordPatternProperty,
  RecordType,
  RecordTypeProperty,
  ReferenceExpression,
  ReferenceType,
  TupleExpression,
  TupleExpressionElement,
  TuplePattern,
  TuplePatternElement,
  TupleType,
  TypeParameter,
  UnitExpression,
  UnitPattern,
  UnitType,
  WrappedExpression,
  WrappedPattern,
  WrappedType,
} from './Ast';
import {
  ExpectedBindingIdentifier,
  ExpectedEnd,
  ExpectedExpression,
  ExpectedGlyph,
  ExpectedIdentifier,
  ExpectedLineSeparator,
  ExpectedPattern,
  ExpectedType,
  ExpressionIntoPatternError,
  ParserErrorType,
  UnexpectedTokenError,
} from './Error';
import {BindingIdentifier, Identifier, ident} from './Identifier';
import {EndToken, Glyph, GlyphToken, IdentifierToken, Lexer} from './Lexer';
import {loc} from './Loc';
import {
  expressionIntoPattern,
  parseCommaListTest,
  parseExpression,
  parseLineSeparatorListTest,
  parsePattern,
  parseType,
} from './Parser';

function lex(source: string): Lexer {
  return Lexer.create(source);
}

describe('type', () => {
  [
    {
      source: '',
      result: Err(UnexpectedTokenError(EndToken(loc('1')), ExpectedType)),
    },
    {
      source: '...',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('1-3'), Glyph.Ellipsis),
          ExpectedType
        )
      ),
    },
    {
      source: 'in',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('1-2'), 'in' as Identifier),
          ExpectedType
        )
      ),
    },
    {
      source: 'foo',
      result: Ok(ReferenceType(loc('1-3'), ident('foo'))),
    },
    {source: '()', result: Ok(UnitType(loc('1-2')))},
    {source: '( )', result: Ok(UnitType(loc('1-3')))},
    {
      source: '(,)',
      result: Err(
        UnexpectedTokenError(GlyphToken(loc('2'), Glyph.Comma), ExpectedType)
      ),
    },
    {
      source: '(foo)',
      result: Ok(
        WrappedType(loc('1-5'), ReferenceType(loc('2-4'), ident('foo')))
      ),
    },
    {
      source: '(foo,)',
      result: Ok(
        WrappedType(loc('1-6'), ReferenceType(loc('2-4'), ident('foo')))
      ),
    },
    {
      source: '(foo, bar)',
      result: Ok(
        TupleType(loc('1-10'), [
          ReferenceType(loc('2-4'), ident('foo')),
          ReferenceType(loc('7-9'), ident('bar')),
        ])
      ),
    },
    {
      source: '(foo, bar, qux)',
      result: Ok(
        TupleType(loc('1-15'), [
          ReferenceType(loc('2-4'), ident('foo')),
          ReferenceType(loc('7-9'), ident('bar')),
          ReferenceType(loc('12-14'), ident('qux')),
        ])
      ),
    },
    {
      source: '(foo, bar, qux, lit)',
      result: Ok(
        TupleType(loc('1-20'), [
          ReferenceType(loc('2-4'), ident('foo')),
          ReferenceType(loc('7-9'), ident('bar')),
          ReferenceType(loc('12-14'), ident('qux')),
          ReferenceType(loc('17-19'), ident('lit')),
        ])
      ),
    },
    {source: '{}', result: Ok(RecordType(loc('1-2'), []))},
    {
      source: '{ foo: T }',
      result: Ok(
        RecordType(loc('1-10'), [
          RecordTypeProperty(
            Name(loc('3-5'), ident('foo')),
            ReferenceType(loc('8'), ident('T'))
          ),
        ])
      ),
    },
    {
      source: '{ foo: T, bar: U }',
      result: Ok(
        RecordType(loc('1-18'), [
          RecordTypeProperty(
            Name(loc('3-5'), ident('foo')),
            ReferenceType(loc('8'), ident('T'))
          ),
          RecordTypeProperty(
            Name(loc('11-13'), ident('bar')),
            ReferenceType(loc('16'), ident('U'))
          ),
        ])
      ),
    },
    {
      source: '{ foo: T, bar: U, qux: V, lit: W }',
      result: Ok(
        RecordType(loc('1-34'), [
          RecordTypeProperty(
            Name(loc('3-5'), ident('foo')),
            ReferenceType(loc('8'), ident('T'))
          ),
          RecordTypeProperty(
            Name(loc('11-13'), ident('bar')),
            ReferenceType(loc('16'), ident('U'))
          ),
          RecordTypeProperty(
            Name(loc('19-21'), ident('qux')),
            ReferenceType(loc('24'), ident('V'))
          ),
          RecordTypeProperty(
            Name(loc('27-29'), ident('lit')),
            ReferenceType(loc('32'), ident('W'))
          ),
        ])
      ),
    },
    {
      source: '{ foo?: T }',
      result: Ok(
        RecordType(loc('1-11'), [
          RecordTypeProperty(
            Name(loc('3-5'), ident('foo')),
            ReferenceType(loc('9'), ident('T')),
            {optional: true}
          ),
        ])
      ),
    },
    {
      source: 'hello.world',
      result: Ok(
        MemberType(
          loc('1-11'),
          ReferenceType(loc('1-5'), ident('hello')),
          Name(loc('7-11'), ident('world'))
        )
      ),
    },
    {
      source: 'foo.bar.qux',
      result: Ok(
        MemberType(
          loc('1-11'),
          MemberType(
            loc('1-7'),
            ReferenceType(loc('1-3'), ident('foo')),
            Name(loc('5-7'), ident('bar'))
          ),
          Name(loc('9-11'), ident('qux'))
        )
      ),
    },
    {
      source: 'foo.bar.qux.lit',
      result: Ok(
        MemberType(
          loc('1-15'),
          MemberType(
            loc('1-11'),
            MemberType(
              loc('1-7'),
              ReferenceType(loc('1-3'), ident('foo')),
              Name(loc('5-7'), ident('bar'))
            ),
            Name(loc('9-11'), ident('qux'))
          ),
          Name(loc('13-15'), ident('lit'))
        )
      ),
    },
    {
      source: 'hello.',
      result: Err(UnexpectedTokenError(EndToken(loc('7')), ExpectedIdentifier)),
    },
    {
      source: 'hello.%',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('7'), Glyph.Percent),
          ExpectedIdentifier
        )
      ),
    },
    {
      source: 'T<>',
      result: Ok(
        GenericType(loc('1-3'), ReferenceType(loc('1'), ident('T')), [])
      ),
    },
    {
      source: 'T<A>',
      result: Ok(
        GenericType(loc('1-4'), ReferenceType(loc('1'), ident('T')), [
          ReferenceType(loc('3'), ident('A')),
        ])
      ),
    },
    {
      source: 'T<A, B>',
      result: Ok(
        GenericType(loc('1-7'), ReferenceType(loc('1'), ident('T')), [
          ReferenceType(loc('3'), ident('A')),
          ReferenceType(loc('6'), ident('B')),
        ])
      ),
    },
    {
      source: 'T<A, B, C, D>',
      result: Ok(
        GenericType(loc('1-13'), ReferenceType(loc('1'), ident('T')), [
          ReferenceType(loc('3'), ident('A')),
          ReferenceType(loc('6'), ident('B')),
          ReferenceType(loc('9'), ident('C')),
          ReferenceType(loc('12'), ident('D')),
        ])
      ),
    },
    {
      source: 'React.Component<Props>',
      result: Ok(
        GenericType(
          loc('1-22'),
          MemberType(
            loc('1-15'),
            ReferenceType(loc('1-5'), ident('React')),
            Name(loc('7-15'), ident('Component'))
          ),
          [ReferenceType(loc('17-21'), ident('Props'))]
        )
      ),
    },
    {
      source: 'A<>.B',
      result: Ok(
        MemberType(
          loc('1-5'),
          GenericType(loc('1-3'), ReferenceType(loc('1'), ident('A')), []),
          Name(loc('5'), ident('B'))
        )
      ),
    },
    {
      source: 'A<><>',
      result: Ok(
        GenericType(
          loc('1-5'),
          GenericType(loc('1-3'), ReferenceType(loc('1'), ident('A')), []),
          []
        )
      ),
    },
    {
      source: '().foo',
      result: Ok(
        MemberType(
          loc('1-6'),
          UnitType(loc('1-2')),
          Name(loc('4-6'), ident('foo'))
        )
      ),
    },
    {
      source: '{}.foo',
      result: Ok(
        MemberType(
          loc('1-6'),
          RecordType(loc('1-2'), []),
          Name(loc('4-6'), ident('foo'))
        )
      ),
    },
    {
      source: '() -> ()',
      result: Ok(FunctionType(loc('1-8'), [], UnitType(loc('7-8')))),
    },
    {
      source: '(a) -> ()',
      result: Ok(
        FunctionType(
          loc('1-9'),
          [ReferenceType(loc('2'), ident('a'))],
          UnitType(loc('8-9'))
        )
      ),
    },
    {
      source: '(a, b) -> ()',
      result: Ok(
        FunctionType(
          loc('1-12'),
          [
            ReferenceType(loc('2'), ident('a')),
            ReferenceType(loc('5'), ident('b')),
          ],
          UnitType(loc('11-12'))
        )
      ),
    },
    {
      source: '(a, b, c, d) -> ()',
      result: Ok(
        FunctionType(
          loc('1-18'),
          [
            ReferenceType(loc('2'), ident('a')),
            ReferenceType(loc('5'), ident('b')),
            ReferenceType(loc('8'), ident('c')),
            ReferenceType(loc('11'), ident('d')),
          ],
          UnitType(loc('17-18'))
        )
      ),
    },
    {
      source: '() -> foo.bar',
      result: Ok(
        FunctionType(
          loc('1-13'),
          [],
          MemberType(
            loc('7-13'),
            ReferenceType(loc('7-9'), ident('foo')),
            Name(loc('11-13'), ident('bar'))
          )
        )
      ),
    },
    {
      source: '() ->',
      result: Err(UnexpectedTokenError(EndToken(loc('6')), ExpectedType)),
    },
    {
      source: 'T -> T',
      result: Ok(
        FunctionType(
          loc('1-6'),
          [ReferenceType(loc('1'), ident('T'))],
          ReferenceType(loc('6'), ident('T'))
        )
      ),
    },
    {
      source: 'x -> foo.bar',
      result: Ok(
        FunctionType(
          loc('1-12'),
          [ReferenceType(loc('1'), ident('x'))],
          MemberType(
            loc('6-12'),
            ReferenceType(loc('6-8'), ident('foo')),
            Name(loc('10-12'), ident('bar'))
          )
        )
      ),
    },
    {
      source: '(X, Y, %, Z)',
      result: Err(
        UnexpectedTokenError(GlyphToken(loc('8'), Glyph.Percent), ExpectedType)
      ),
    },
    {
      source: 'T<X, Y, %, Z>',
      result: Err(
        UnexpectedTokenError(GlyphToken(loc('9'), Glyph.Percent), ExpectedType)
      ),
    },
    {
      source: '<T> T',
      result: Ok(
        QuantifiedType(
          loc('1-5'),
          [TypeParameter(Name(loc('2'), ident('T')), [])],
          ReferenceType(loc('5'), ident('T'))
        )
      ),
    },
    {
      source: '<T> Foo<T>',
      result: Ok(
        QuantifiedType(
          loc('1-10'),
          [TypeParameter(Name(loc('2'), ident('T')), [])],
          GenericType(loc('5-10'), ReferenceType(loc('5-7'), ident('Foo')), [
            ReferenceType(loc('9'), ident('T')),
          ])
        )
      ),
    },
    {
      source: '<T>(T) -> T',
      result: Ok(
        QuantifiedType(
          loc('1-11'),
          [TypeParameter(Name(loc('2'), ident('T')), [])],
          FunctionType(
            loc('4-11'),
            [ReferenceType(loc('5'), ident('T'))],
            ReferenceType(loc('11'), ident('T'))
          )
        )
      ),
    },
    {
      source: '<T> T -> T',
      result: Ok(
        QuantifiedType(
          loc('1-10'),
          [TypeParameter(Name(loc('2'), ident('T')), [])],
          FunctionType(
            loc('5-10'),
            [ReferenceType(loc('5'), ident('T'))],
            ReferenceType(loc('10'), ident('T'))
          )
        )
      ),
    },
    {
      source: '<T> %',
      result: Err(
        UnexpectedTokenError(GlyphToken(loc('5'), Glyph.Percent), ExpectedType)
      ),
    },
    {
      source: '<T: A> T',
      result: Ok(
        QuantifiedType(
          loc('1-8'),
          [
            TypeParameter(Name(loc('2'), ident('T')), [
              ReferenceType(loc('5'), ident('A')),
            ]),
          ],
          ReferenceType(loc('8'), ident('T'))
        )
      ),
    },
    {
      source: '<T: A + B> T',
      result: Ok(
        QuantifiedType(
          loc('1-12'),
          [
            TypeParameter(Name(loc('2'), ident('T')), [
              ReferenceType(loc('5'), ident('A')),
              ReferenceType(loc('9'), ident('B')),
            ]),
          ],
          ReferenceType(loc('12'), ident('T'))
        )
      ),
    },
    {
      source: '<T: A + B + C + D> T',
      result: Ok(
        QuantifiedType(
          loc('1-20'),
          [
            TypeParameter(Name(loc('2'), ident('T')), [
              ReferenceType(loc('5'), ident('A')),
              ReferenceType(loc('9'), ident('B')),
              ReferenceType(loc('13'), ident('C')),
              ReferenceType(loc('17'), ident('D')),
            ]),
          ],
          ReferenceType(loc('20'), ident('T'))
        )
      ),
    },
    {
      source: '<T: > T',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('5'), Glyph.GreaterThan),
          ExpectedType
        )
      ),
    },
    {
      source: '<T: %> T',
      result: Err(
        UnexpectedTokenError(GlyphToken(loc('5'), Glyph.Percent), ExpectedType)
      ),
    },
    {
      source: '<T: A + %> T',
      result: Err(
        UnexpectedTokenError(GlyphToken(loc('9'), Glyph.Percent), ExpectedType)
      ),
    },
    {
      source: '<T: A B> T',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('7'), ident('B')),
          ExpectedGlyph(Glyph.Comma)
        )
      ),
    },
  ].forEach(({source, result}) => {
    test(source, () => {
      expect(parseType(lex(source))).toEqual(result);
    });
  });
});

describe('expression', () => {
  [
    {
      source: 'foo',
      result: Ok(ReferenceExpression(loc('1-3'), ident('foo'))),
    },
    {
      source: 'in',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('1-2'), 'in' as Identifier),
          ExpectedExpression
        )
      ),
    },
    {
      source: '_',
      result: Ok(HoleExpression(loc('1'))),
    },
    {
      source: '()',
      result: Ok(UnitExpression(loc('1-2'))),
    },
    {
      source: '(foo)',
      result: Ok(
        WrappedExpression(
          loc('1-5'),
          ReferenceExpression(loc('2-4'), ident('foo')),
          undefined
        )
      ),
    },
    {
      source: '(a, b)',
      result: Ok(
        TupleExpression(loc('1-6'), [
          TupleExpressionElement(
            ReferenceExpression(loc('2'), ident('a')),
            undefined
          ),
          TupleExpressionElement(
            ReferenceExpression(loc('5'), ident('b')),
            undefined
          ),
        ])
      ),
    },
    {
      source: '(a, b, c, d)',
      result: Ok(
        TupleExpression(loc('1-12'), [
          TupleExpressionElement(
            ReferenceExpression(loc('2'), ident('a')),
            undefined
          ),
          TupleExpressionElement(
            ReferenceExpression(loc('5'), ident('b')),
            undefined
          ),
          TupleExpressionElement(
            ReferenceExpression(loc('8'), ident('c')),
            undefined
          ),
          TupleExpressionElement(
            ReferenceExpression(loc('11'), ident('d')),
            undefined
          ),
        ])
      ),
    },
    {
      source: '(,)',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('2'), Glyph.Comma),
          ExpectedExpression
        )
      ),
    },
    {
      source: '(foo,)',
      result: Ok(
        WrappedExpression(
          loc('1-6'),
          ReferenceExpression(loc('2-4'), ident('foo')),
          undefined
        )
      ),
    },
    {
      source: '(a, b,)',
      result: Ok(
        TupleExpression(loc('1-7'), [
          TupleExpressionElement(
            ReferenceExpression(loc('2'), ident('a')),
            undefined
          ),
          TupleExpressionElement(
            ReferenceExpression(loc('5'), ident('b')),
            undefined
          ),
        ])
      ),
    },
    {
      source: '(a, b, c, d,)',
      result: Ok(
        TupleExpression(loc('1-13'), [
          TupleExpressionElement(
            ReferenceExpression(loc('2'), ident('a')),
            undefined
          ),
          TupleExpressionElement(
            ReferenceExpression(loc('5'), ident('b')),
            undefined
          ),
          TupleExpressionElement(
            ReferenceExpression(loc('8'), ident('c')),
            undefined
          ),
          TupleExpressionElement(
            ReferenceExpression(loc('11'), ident('d')),
            undefined
          ),
        ])
      ),
    },
    {
      source: '(x:)',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('4'), Glyph.ParenRight),
          ExpectedType
        )
      ),
    },
    {
      source: '(x: T)',
      result: Ok(
        WrappedExpression(
          loc('1-6'),
          ReferenceExpression(loc('2'), ident('x')),
          ReferenceType(loc('5'), ident('T'))
        )
      ),
    },
    {
      source: '(a: A, b: B)',
      result: Ok(
        TupleExpression(loc('1-12'), [
          TupleExpressionElement(
            ReferenceExpression(loc('2'), ident('a')),
            ReferenceType(loc('5'), ident('A'))
          ),
          TupleExpressionElement(
            ReferenceExpression(loc('8'), ident('b')),
            ReferenceType(loc('11'), ident('B'))
          ),
        ])
      ),
    },
    {
      source: '(a: A, b: B, c: C, d: D)',
      result: Ok(
        TupleExpression(loc('1-24'), [
          TupleExpressionElement(
            ReferenceExpression(loc('2'), ident('a')),
            ReferenceType(loc('5'), ident('A'))
          ),
          TupleExpressionElement(
            ReferenceExpression(loc('8'), ident('b')),
            ReferenceType(loc('11'), ident('B'))
          ),
          TupleExpressionElement(
            ReferenceExpression(loc('14'), ident('c')),
            ReferenceType(loc('17'), ident('C'))
          ),
          TupleExpressionElement(
            ReferenceExpression(loc('20'), ident('d')),
            ReferenceType(loc('23'), ident('D'))
          ),
        ])
      ),
    },
    {
      source: '(x: T,)',
      result: Ok(
        WrappedExpression(
          loc('1-7'),
          ReferenceExpression(loc('2'), ident('x')),
          ReferenceType(loc('5'), ident('T'))
        )
      ),
    },
    {
      source: '(a: A, b: B,)',
      result: Ok(
        TupleExpression(loc('1-13'), [
          TupleExpressionElement(
            ReferenceExpression(loc('2'), ident('a')),
            ReferenceType(loc('5'), ident('A'))
          ),
          TupleExpressionElement(
            ReferenceExpression(loc('8'), ident('b')),
            ReferenceType(loc('11'), ident('B'))
          ),
        ])
      ),
    },
    {
      source: '{}',
      result: Ok(RecordExpression(loc('1-2'), undefined, [])),
    },
    {
      source: '{ foo }',
      result: Ok(
        RecordExpression(loc('1-7'), undefined, [
          RecordExpressionProperty(
            Name(loc('3-5'), ident('foo')),
            ReferenceExpression(loc('3-5'), ident('foo')),
            undefined
          ),
        ])
      ),
    },
    {
      source: '{ foo, bar }',
      result: Ok(
        RecordExpression(loc('1-12'), undefined, [
          RecordExpressionProperty(
            Name(loc('3-5'), ident('foo')),
            ReferenceExpression(loc('3-5'), ident('foo')),
            undefined
          ),
          RecordExpressionProperty(
            Name(loc('8-10'), ident('bar')),
            ReferenceExpression(loc('8-10'), ident('bar')),
            undefined
          ),
        ])
      ),
    },
    {
      source: '{ foo, bar, qux, lit }',
      result: Ok(
        RecordExpression(loc('1-22'), undefined, [
          RecordExpressionProperty(
            Name(loc('3-5'), ident('foo')),
            ReferenceExpression(loc('3-5'), ident('foo')),
            undefined
          ),
          RecordExpressionProperty(
            Name(loc('8-10'), ident('bar')),
            ReferenceExpression(loc('8-10'), ident('bar')),
            undefined
          ),
          RecordExpressionProperty(
            Name(loc('13-15'), ident('qux')),
            ReferenceExpression(loc('13-15'), ident('qux')),
            undefined
          ),
          RecordExpressionProperty(
            Name(loc('18-20'), ident('lit')),
            ReferenceExpression(loc('18-20'), ident('lit')),
            undefined
          ),
        ])
      ),
    },
    {
      source: '{ foo: T }',
      result: Ok(
        RecordExpression(loc('1-10'), undefined, [
          RecordExpressionProperty(
            Name(loc('3-5'), ident('foo')),
            ReferenceExpression(loc('3-5'), ident('foo')),
            ReferenceType(loc('8'), ident('T'))
          ),
        ])
      ),
    },
    {
      source: '{ foo: T, bar: U }',
      result: Ok(
        RecordExpression(loc('1-18'), undefined, [
          RecordExpressionProperty(
            Name(loc('3-5'), ident('foo')),
            ReferenceExpression(loc('3-5'), ident('foo')),
            ReferenceType(loc('8'), ident('T'))
          ),
          RecordExpressionProperty(
            Name(loc('11-13'), ident('bar')),
            ReferenceExpression(loc('11-13'), ident('bar')),
            ReferenceType(loc('16'), ident('U'))
          ),
        ])
      ),
    },
    {
      source: '{ foo: T, bar: U, qux: V, lit: W }',
      result: Ok(
        RecordExpression(loc('1-34'), undefined, [
          RecordExpressionProperty(
            Name(loc('3-5'), ident('foo')),
            ReferenceExpression(loc('3-5'), ident('foo')),
            ReferenceType(loc('8'), ident('T'))
          ),
          RecordExpressionProperty(
            Name(loc('11-13'), ident('bar')),
            ReferenceExpression(loc('11-13'), ident('bar')),
            ReferenceType(loc('16'), ident('U'))
          ),
          RecordExpressionProperty(
            Name(loc('19-21'), ident('qux')),
            ReferenceExpression(loc('19-21'), ident('qux')),
            ReferenceType(loc('24'), ident('V'))
          ),
          RecordExpressionProperty(
            Name(loc('27-29'), ident('lit')),
            ReferenceExpression(loc('27-29'), ident('lit')),
            ReferenceType(loc('32'), ident('W'))
          ),
        ])
      ),
    },
    {
      source: '{ foo = foo2 }',
      result: Ok(
        RecordExpression(loc('1-14'), undefined, [
          RecordExpressionProperty(
            Name(loc('3-5'), ident('foo')),
            ReferenceExpression(loc('9-12'), ident('foo2')),
            undefined
          ),
        ])
      ),
    },
    {
      source: '{ foo = foo2, bar = bar2 }',
      result: Ok(
        RecordExpression(loc('1-26'), undefined, [
          RecordExpressionProperty(
            Name(loc('3-5'), ident('foo')),
            ReferenceExpression(loc('9-12'), ident('foo2')),
            undefined
          ),
          RecordExpressionProperty(
            Name(loc('15-17'), ident('bar')),
            ReferenceExpression(loc('21-24'), ident('bar2')),
            undefined
          ),
        ])
      ),
    },
    {
      source: '{ foo: T = x }',
      result: Ok(
        RecordExpression(loc('1-14'), undefined, [
          RecordExpressionProperty(
            Name(loc('3-5'), ident('foo')),
            ReferenceExpression(loc('12'), ident('x')),
            ReferenceType(loc('8'), ident('T'))
          ),
        ])
      ),
    },
    {
      source: '{ foo?: T }',
      result: Ok(
        RecordExpression(loc('1-11'), undefined, [
          RecordExpressionProperty(
            Name(loc('3-5'), ident('foo')),
            ReferenceExpression(loc('3-5'), ident('foo')),
            ReferenceType(loc('9'), ident('T')),
            {optional: true}
          ),
        ])
      ),
    },
    {
      source: '{ foo? }',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('8'), Glyph.BraceRight),
          ExpectedGlyph(Glyph.Colon)
        )
      ),
    },
    {
      source: "{ in = in' }",
      result: Ok(
        RecordExpression(loc('1-12'), undefined, [
          RecordExpressionProperty(
            Name(loc('3-4'), 'in' as BindingIdentifier),
            ReferenceExpression(loc('8-10'), ident("in'")),
            undefined
          ),
        ])
      ),
    },
    {
      source: '{ in }',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('3-4'), 'in' as Identifier),
          ExpectedBindingIdentifier
        )
      ),
    },
    {
      source: '{ {} | }',
      result: Ok(
        RecordExpression(
          loc('1-8'),
          RecordExpression(loc('3-4'), undefined, []),
          []
        )
      ),
    },
    {
      source: '{ {} | a = x }',
      result: Ok(
        RecordExpression(
          loc('1-14'),
          RecordExpression(loc('3-4'), undefined, []),
          [
            RecordExpressionProperty(
              Name(loc('8'), ident('a')),
              ReferenceExpression(loc('12'), ident('x')),
              undefined
            ),
          ]
        )
      ),
    },
    {
      source: '{ {} | a = x, b = y, c = z }',
      result: Ok(
        RecordExpression(
          loc('1-28'),
          RecordExpression(loc('3-4'), undefined, []),
          [
            RecordExpressionProperty(
              Name(loc('8'), ident('a')),
              ReferenceExpression(loc('12'), ident('x')),
              undefined
            ),
            RecordExpressionProperty(
              Name(loc('15'), ident('b')),
              ReferenceExpression(loc('19'), ident('y')),
              undefined
            ),
            RecordExpressionProperty(
              Name(loc('22'), ident('c')),
              ReferenceExpression(loc('26'), ident('z')),
              undefined
            ),
          ]
        )
      ),
    },
    {
      source: '{ yo | }',
      result: Ok(
        RecordExpression(
          loc('1-8'),
          ReferenceExpression(loc('3-4'), ident('yo')),
          []
        )
      ),
    },
    {
      source: '{ yo | a = x }',
      result: Ok(
        RecordExpression(
          loc('1-14'),
          ReferenceExpression(loc('3-4'), ident('yo')),
          [
            RecordExpressionProperty(
              Name(loc('8'), ident('a')),
              ReferenceExpression(loc('12'), ident('x')),
              undefined
            ),
          ]
        )
      ),
    },
    {
      source: '{ yo | a = x, b = y, c = z }',
      result: Ok(
        RecordExpression(
          loc('1-28'),
          ReferenceExpression(loc('3-4'), ident('yo')),
          [
            RecordExpressionProperty(
              Name(loc('8'), ident('a')),
              ReferenceExpression(loc('12'), ident('x')),
              undefined
            ),
            RecordExpressionProperty(
              Name(loc('15'), ident('b')),
              ReferenceExpression(loc('19'), ident('y')),
              undefined
            ),
            RecordExpressionProperty(
              Name(loc('22'), ident('c')),
              ReferenceExpression(loc('26'), ident('z')),
              undefined
            ),
          ]
        )
      ),
    },
    {
      source: '{ if x then y else z | a = b }',
      result: Ok(
        RecordExpression(
          loc('1-30'),
          ConditionalExpression(
            loc('3-20'),
            ReferenceExpression(loc('6'), ident('x')),
            ReferenceExpression(loc('13'), ident('y')),
            ReferenceExpression(loc('20'), ident('z'))
          ),
          [
            RecordExpressionProperty(
              Name(loc('24'), ident('a')),
              ReferenceExpression(loc('28'), ident('b')),
              undefined
            ),
          ]
        )
      ),
    },
    {
      source: '{ x is T | a = b }',
      result: Ok(
        RecordExpression(
          loc('1-18'),
          PatternExpression(
            loc('3-8'),
            ReferenceExpression(loc('3'), ident('x')),
            BindingPattern(loc('8'), ident('T'))
          ),
          [
            RecordExpressionProperty(
              Name(loc('12'), ident('a')),
              ReferenceExpression(loc('16'), ident('b')),
              undefined
            ),
          ]
        )
      ),
    },
    {
      source: '{ x == y | a = b }',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('5-6'), Glyph.EqualsDouble),
          ExpectedGlyph(Glyph.Bar)
        )
      ),
    },
    {
      source: '{ in | }',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('3-4'), 'in' as Identifier),
          ExpectedExpression
        )
      ),
    },
    {
      source: '[]',
      result: Ok(ListExpression(loc('1-2'), [])),
    },
    {
      source: '[a]',
      result: Ok(
        ListExpression(loc('1-3'), [ReferenceExpression(loc('2'), ident('a'))])
      ),
    },
    {
      source: '[a, b]',
      result: Ok(
        ListExpression(loc('1-6'), [
          ReferenceExpression(loc('2'), ident('a')),
          ReferenceExpression(loc('5'), ident('b')),
        ])
      ),
    },
    {
      source: '[a, b, c, d]',
      result: Ok(
        ListExpression(loc('1-12'), [
          ReferenceExpression(loc('2'), ident('a')),
          ReferenceExpression(loc('5'), ident('b')),
          ReferenceExpression(loc('8'), ident('c')),
          ReferenceExpression(loc('11'), ident('d')),
        ])
      ),
    },
    {
      source: 'match x: ()',
      result: Ok(
        MatchExpression(
          loc('1-11'),
          ReferenceExpression(loc('7'), ident('x')),
          []
        )
      ),
    },
    {
      source: 'match x: (y)',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('12'), Glyph.ParenRight),
          ExpectedGlyph(Glyph.Arrow)
        )
      ),
    },
    {
      source: 'match x: ([] -> y; _ -> z)',
      result: Ok(
        MatchExpression(
          loc('1-26'),
          ReferenceExpression(loc('7'), ident('x')),
          [
            MatchCase(
              [ListPattern(loc('11-12'), [])],
              undefined,
              ReferenceExpression(loc('17'), ident('y'))
            ),
            MatchCase(
              [HolePattern(loc('20'))],
              undefined,
              ReferenceExpression(loc('25'), ident('z'))
            ),
          ]
        )
      ),
    },
    {
      source: 'match x: (\n  [] -> y\n  _ -> z\n)',
      result: Ok(
        MatchExpression(
          loc('1:1-4:1'),
          ReferenceExpression(loc('1:7'), ident('x')),
          [
            MatchCase(
              [ListPattern(loc('2:3-2:4'), [])],
              undefined,
              ReferenceExpression(loc('2:9'), ident('y'))
            ),
            MatchCase(
              [HolePattern(loc('3:3'))],
              undefined,
              ReferenceExpression(loc('3:8'), ident('z'))
            ),
          ]
        )
      ),
    },
    {
      source: 'match x: (_ -> y; () -> z)',
      result: Ok(
        MatchExpression(
          loc('1-26'),
          ReferenceExpression(loc('7'), ident('x')),
          [
            MatchCase(
              [HolePattern(loc('11'))],
              undefined,
              ReferenceExpression(loc('16'), ident('y'))
            ),
            MatchCase(
              [UnitPattern(loc('19-20'))],
              undefined,
              ReferenceExpression(loc('25'), ident('z'))
            ),
          ]
        )
      ),
    },
    {
      source: 'match x: (\n  _ -> y\n  () -> z\n)',
      result: Ok(
        MatchExpression(
          loc('1:1-4:1'),
          ReferenceExpression(loc('1:7'), ident('x')),
          [
            MatchCase(
              [HolePattern(loc('2:3'))],
              undefined,
              ReferenceExpression(loc('2:8'), ident('y'))
            ),
            MatchCase(
              [UnitPattern(loc('3:3-3:4'))],
              undefined,
              ReferenceExpression(loc('3:9'), ident('z'))
            ),
          ]
        )
      ),
    },
    {
      source: 'match x: (\n  _ -> y()\n  () -> z\n)',
      result: Ok(
        MatchExpression(
          loc('1:1-4:1'),
          ReferenceExpression(loc('1:7'), ident('x')),
          [
            MatchCase(
              [HolePattern(loc('2:3'))],
              undefined,
              CallExpression(
                loc('2:8-2:10'),
                ReferenceExpression(loc('2:8'), ident('y')),
                [],
                []
              )
            ),
            MatchCase(
              [UnitPattern(loc('3:3-3:4'))],
              undefined,
              ReferenceExpression(loc('3:9'), ident('z'))
            ),
          ]
        )
      ),
    },
    {
      source: 'match x: (_ -> y () -> z)',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('21-22'), Glyph.Arrow),
          ExpectedLineSeparator
        )
      ),
    },
    {
      source: 'match x: (_ | _ -> y)',
      result: Ok(
        MatchExpression(
          loc('1-21'),
          ReferenceExpression(loc('7'), ident('x')),
          [
            MatchCase(
              [HolePattern(loc('11')), HolePattern(loc('15'))],
              undefined,
              ReferenceExpression(loc('20'), ident('y'))
            ),
          ]
        )
      ),
    },
    {
      source: 'match x: (_ if y -> z)',
      result: Ok(
        MatchExpression(
          loc('1-22'),
          ReferenceExpression(loc('7'), ident('x')),
          [
            MatchCase(
              [HolePattern(loc('11'))],
              ReferenceExpression(loc('16'), ident('y')),
              ReferenceExpression(loc('21'), ident('z'))
            ),
          ]
        )
      ),
    },
    {
      source: 'match a: (_ if b -> c -> d)',
      result: Ok(
        MatchExpression(
          loc('1-27'),
          ReferenceExpression(loc('7'), ident('a')),
          [
            MatchCase(
              [HolePattern(loc('11'))],
              ReferenceExpression(loc('16'), ident('b')),
              FunctionExpression(
                loc('21-26'),
                [
                  FunctionParameter(
                    BindingPattern(loc('21'), ident('c')),
                    undefined
                  ),
                ],
                ReferenceExpression(loc('26'), ident('d'))
              )
            ),
          ]
        )
      ),
    },
    {
      source: 'match a: (_ if () -> c -> d)',
      result: Ok(
        MatchExpression(
          loc('1-28'),
          ReferenceExpression(loc('7'), ident('a')),
          [
            MatchCase(
              [HolePattern(loc('11'))],
              UnitExpression(loc('16-17')),
              FunctionExpression(
                loc('22-27'),
                [
                  FunctionParameter(
                    BindingPattern(loc('22'), ident('c')),
                    undefined
                  ),
                ],
                ReferenceExpression(loc('27'), ident('d'))
              )
            ),
          ]
        )
      ),
    },
    {
      source: 'o.p',
      result: Ok(
        MemberExpression(
          loc('1-3'),
          ReferenceExpression(loc('1'), ident('o')),
          Name(loc('3'), ident('p'))
        )
      ),
    },
    {
      source: '().p',
      result: Ok(
        MemberExpression(
          loc('1-4'),
          UnitExpression(loc('1-2')),
          Name(loc('4'), ident('p'))
        )
      ),
    },
    {
      source: '(a, b).p',
      result: Ok(
        MemberExpression(
          loc('1-8'),
          TupleExpression(loc('1-6'), [
            TupleExpressionElement(
              ReferenceExpression(loc('2'), ident('a')),
              undefined
            ),
            TupleExpressionElement(
              ReferenceExpression(loc('5'), ident('b')),
              undefined
            ),
          ]),
          Name(loc('8'), ident('p'))
        )
      ),
    },
    {
      source: '{}.p',
      result: Ok(
        MemberExpression(
          loc('1-4'),
          RecordExpression(loc('1-2'), undefined, []),
          Name(loc('4'), ident('p'))
        )
      ),
    },
    {
      source: '{ a = b }.p',
      result: Ok(
        MemberExpression(
          loc('1-11'),
          RecordExpression(loc('1-9'), undefined, [
            RecordExpressionProperty(
              Name(loc('3'), ident('a')),
              ReferenceExpression(loc('7'), ident('b')),
              undefined
            ),
          ]),
          Name(loc('11'), ident('p'))
        )
      ),
    },
    {
      source: '[].p',
      result: Ok(
        MemberExpression(
          loc('1-4'),
          ListExpression(loc('1-2'), []),
          Name(loc('4'), ident('p'))
        )
      ),
    },
    {
      source: 'o.a.b.c',
      result: Ok(
        MemberExpression(
          loc('1-7'),
          MemberExpression(
            loc('1-5'),
            MemberExpression(
              loc('1-3'),
              ReferenceExpression(loc('1'), ident('o')),
              Name(loc('3'), ident('a'))
            ),
            Name(loc('5'), ident('b'))
          ),
          Name(loc('7'), ident('c'))
        )
      ),
    },
    {
      source: 'f().p',
      result: Ok(
        MemberExpression(
          loc('1-5'),
          CallExpression(
            loc('1-3'),
            ReferenceExpression(loc('1'), ident('f')),
            [],
            []
          ),
          Name(loc('5'), ident('p'))
        )
      ),
    },
    {
      source: '(o).p',
      result: Ok(
        MemberExpression(
          loc('1-5'),
          WrappedExpression(
            loc('1-3'),
            ReferenceExpression(loc('2'), ident('o')),
            undefined
          ),
          Name(loc('5'), ident('p'))
        )
      ),
    },
    {
      source: 'f()',
      result: Ok(
        CallExpression(
          loc('1-3'),
          ReferenceExpression(loc('1'), ident('f')),
          [],
          []
        )
      ),
    },
    {
      source: 'f(a)',
      result: Ok(
        CallExpression(
          loc('1-4'),
          ReferenceExpression(loc('1'), ident('f')),
          [],
          [ReferenceExpression(loc('3'), ident('a'))]
        )
      ),
    },
    {
      source: 'f(a, b)',
      result: Ok(
        CallExpression(
          loc('1-7'),
          ReferenceExpression(loc('1'), ident('f')),
          [],
          [
            ReferenceExpression(loc('3'), ident('a')),
            ReferenceExpression(loc('6'), ident('b')),
          ]
        )
      ),
    },
    {
      source: 'f(a, b, c, d)',
      result: Ok(
        CallExpression(
          loc('1-13'),
          ReferenceExpression(loc('1'), ident('f')),
          [],
          [
            ReferenceExpression(loc('3'), ident('a')),
            ReferenceExpression(loc('6'), ident('b')),
            ReferenceExpression(loc('9'), ident('c')),
            ReferenceExpression(loc('12'), ident('d')),
          ]
        )
      ),
    },
    {
      source: 'f\n()',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('2:1'), Glyph.ParenLeft),
          ExpectedEnd
        )
      ),
    },
    {
      source: 'f<>',
      result: Err(
        UnexpectedTokenError(EndToken(loc('4')), ExpectedGlyph(Glyph.ParenLeft))
      ),
    },
    {
      source: 'f<>()',
      result: Ok(
        CallExpression(
          loc('1-5'),
          ReferenceExpression(loc('1'), ident('f')),
          [],
          []
        )
      ),
    },
    {
      source: 'f\n<>()',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('2:1'), Glyph.LessThan),
          ExpectedEnd
        )
      ),
    },
    {
      source: 'f<>\n()',
      result: Ok(
        CallExpression(
          loc('1:1-2:2'),
          ReferenceExpression(loc('1'), ident('f')),
          [],
          []
        )
      ),
    },
    {
      source: 'f\n<>\n()',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('2:1'), Glyph.LessThan),
          ExpectedEnd
        )
      ),
    },
    {
      source: 'f<A>()',
      result: Ok(
        CallExpression(
          loc('1-6'),
          ReferenceExpression(loc('1'), ident('f')),
          [ReferenceType(loc('3'), ident('A'))],
          []
        )
      ),
    },
    {
      source: 'f<A, B>()',
      result: Ok(
        CallExpression(
          loc('1-9'),
          ReferenceExpression(loc('1'), ident('f')),
          [
            ReferenceType(loc('3'), ident('A')),
            ReferenceType(loc('6'), ident('B')),
          ],
          []
        )
      ),
    },
    {
      source: 'f<A, B, C, D>()',
      result: Ok(
        CallExpression(
          loc('1-15'),
          ReferenceExpression(loc('1'), ident('f')),
          [
            ReferenceType(loc('3'), ident('A')),
            ReferenceType(loc('6'), ident('B')),
            ReferenceType(loc('9'), ident('C')),
            ReferenceType(loc('12'), ident('D')),
          ],
          []
        )
      ),
    },
    {
      source: 'f<A, B>(c, d)',
      result: Ok(
        CallExpression(
          loc('1-13'),
          ReferenceExpression(loc('1'), ident('f')),
          [
            ReferenceType(loc('3'), ident('A')),
            ReferenceType(loc('6'), ident('B')),
          ],
          [
            ReferenceExpression(loc('9'), ident('c')),
            ReferenceExpression(loc('12'), ident('d')),
          ]
        )
      ),
    },
    {
      source: '()()',
      result: Ok(
        CallExpression(loc('1-4'), UnitExpression(loc('1-2')), [], [])
      ),
    },
    {
      source: '().p()',
      result: Ok(
        CallExpression(
          loc('1-6'),
          MemberExpression(
            loc('1-4'),
            UnitExpression(loc('1-2')),
            Name(loc('4'), ident('p'))
          ),
          [],
          []
        )
      ),
    },
    {
      source: 'x -> y',
      result: Ok(
        FunctionExpression(
          loc('1-6'),
          [FunctionParameter(BindingPattern(loc('1'), ident('x')), undefined)],
          ReferenceExpression(loc('6'), ident('y'))
        )
      ),
    },
    {
      source: '() -> x',
      result: Ok(
        FunctionExpression(
          loc('1-7'),
          [],
          ReferenceExpression(loc('7'), ident('x'))
        )
      ),
    },
    {
      source: '(x) -> y',
      result: Ok(
        FunctionExpression(
          loc('1-8'),
          [FunctionParameter(BindingPattern(loc('2'), ident('x')), undefined)],
          ReferenceExpression(loc('8'), ident('y'))
        )
      ),
    },
    {
      source: '(x, y) -> z',
      result: Ok(
        FunctionExpression(
          loc('1-11'),
          [
            FunctionParameter(BindingPattern(loc('2'), ident('x')), undefined),
            FunctionParameter(BindingPattern(loc('5'), ident('y')), undefined),
          ],
          ReferenceExpression(loc('11'), ident('z'))
        )
      ),
    },
    {
      source: '(a, b, c, d) -> e',
      result: Ok(
        FunctionExpression(
          loc('1-17'),
          [
            FunctionParameter(BindingPattern(loc('2'), ident('a')), undefined),
            FunctionParameter(BindingPattern(loc('5'), ident('b')), undefined),
            FunctionParameter(BindingPattern(loc('8'), ident('c')), undefined),
            FunctionParameter(BindingPattern(loc('11'), ident('d')), undefined),
          ],
          ReferenceExpression(loc('17'), ident('e'))
        )
      ),
    },
    {
      source: '(a: A) -> b',
      result: Ok(
        FunctionExpression(
          loc('1-11'),
          [
            FunctionParameter(
              BindingPattern(loc('2'), ident('a')),
              ReferenceType(loc('5'), ident('A'))
            ),
          ],
          ReferenceExpression(loc('11'), ident('b'))
        )
      ),
    },
    {
      source: '(a: A, b: B) -> c',
      result: Ok(
        FunctionExpression(
          loc('1-17'),
          [
            FunctionParameter(
              BindingPattern(loc('2'), ident('a')),
              ReferenceType(loc('5'), ident('A'))
            ),
            FunctionParameter(
              BindingPattern(loc('8'), ident('b')),
              ReferenceType(loc('11'), ident('B'))
            ),
          ],
          ReferenceExpression(loc('17'), ident('c'))
        )
      ),
    },
    {
      source: '(a, b: B) -> c',
      result: Ok(
        FunctionExpression(
          loc('1-14'),
          [
            FunctionParameter(BindingPattern(loc('2'), ident('a')), undefined),
            FunctionParameter(
              BindingPattern(loc('5'), ident('b')),
              ReferenceType(loc('8'), ident('B'))
            ),
          ],
          ReferenceExpression(loc('14'), ident('c'))
        )
      ),
    },
    {
      source: '(a: A, b) -> c',
      result: Ok(
        FunctionExpression(
          loc('1-14'),
          [
            FunctionParameter(
              BindingPattern(loc('2'), ident('a')),
              ReferenceType(loc('5'), ident('A'))
            ),
            FunctionParameter(BindingPattern(loc('8'), ident('b')), undefined),
          ],
          ReferenceExpression(loc('14'), ident('c'))
        )
      ),
    },
    {
      source: '(()) -> x',
      result: Ok(
        FunctionExpression(
          loc('1-9'),
          [FunctionParameter(UnitPattern(loc('2-3')), undefined)],
          ReferenceExpression(loc('9'), ident('x'))
        )
      ),
    },
    {
      source: '((x, y)) -> z',
      result: Ok(
        FunctionExpression(
          loc('1-13'),
          [
            FunctionParameter(
              TuplePattern(loc('2-7'), [
                TuplePatternElement(
                  BindingPattern(loc('3'), ident('x')),
                  undefined
                ),
                TuplePatternElement(
                  BindingPattern(loc('6'), ident('y')),
                  undefined
                ),
              ]),
              undefined
            ),
          ],
          ReferenceExpression(loc('13'), ident('z'))
        )
      ),
    },
    {
      source: '((a: A, b: B)) -> c',
      result: Ok(
        FunctionExpression(
          loc('1-19'),
          [
            FunctionParameter(
              TuplePattern(loc('2-13'), [
                TuplePatternElement(
                  BindingPattern(loc('3'), ident('a')),
                  ReferenceType(loc('6'), ident('A'))
                ),
                TuplePatternElement(
                  BindingPattern(loc('9'), ident('b')),
                  ReferenceType(loc('12'), ident('B'))
                ),
              ]),
              undefined
            ),
          ],
          ReferenceExpression(loc('19'), ident('c'))
        )
      ),
    },
    {
      source: '({}) -> x',
      result: Ok(
        FunctionExpression(
          loc('1-9'),
          [FunctionParameter(RecordPattern(loc('2-3'), []), undefined)],
          ReferenceExpression(loc('9'), ident('x'))
        )
      ),
    },
    {
      source: 'x is ()',
      result: Ok(
        PatternExpression(
          loc('1-7'),
          ReferenceExpression(loc('1'), ident('x')),
          UnitPattern(loc('6-7'))
        )
      ),
    },
    {
      source: 'in is ()',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('1-2'), 'in' as Identifier),
          ExpectedExpression
        )
      ),
    },
    {
      source: '() is ()',
      result: Ok(
        PatternExpression(
          loc('1-8'),
          UnitExpression(loc('1-2')),
          UnitPattern(loc('7-8'))
        )
      ),
    },
    {
      source: '() is () is ()',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('10-11'), ident('is')),
          ExpectedEnd
        )
      ),
    },
    {
      source: 'x\nis ()',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('2:1-2:2'), ident('is')),
          ExpectedEnd
        )
      ),
    },
    {
      source: 'if x then y else z',
      result: Ok(
        ConditionalExpression(
          loc('1-18'),
          ReferenceExpression(loc('4'), ident('x')),
          ReferenceExpression(loc('11'), ident('y')),
          ReferenceExpression(loc('18'), ident('z'))
        )
      ),
    },
    {
      source: 'if x then y',
      result: Ok(
        ConditionalExpression(
          loc('1-11'),
          ReferenceExpression(loc('4'), ident('x')),
          ReferenceExpression(loc('11'), ident('y')),
          undefined
        )
      ),
    },
    {
      source: 'if x then y else z()',
      result: Ok(
        ConditionalExpression(
          loc('1-20'),
          ReferenceExpression(loc('4'), ident('x')),
          ReferenceExpression(loc('11'), ident('y')),
          CallExpression(
            loc('18-20'),
            ReferenceExpression(loc('18'), ident('z')),
            [],
            []
          )
        )
      ),
    },
    {
      source: 'if x then y()',
      result: Ok(
        ConditionalExpression(
          loc('1-13'),
          ReferenceExpression(loc('4'), ident('x')),
          CallExpression(
            loc('11-13'),
            ReferenceExpression(loc('11'), ident('y')),
            [],
            []
          ),
          undefined
        )
      ),
    },
    {
      source: 'if a then b else if c then d else e',
      result: Ok(
        ConditionalExpression(
          loc('1-35'),
          ReferenceExpression(loc('4'), ident('a')),
          ReferenceExpression(loc('11'), ident('b')),
          ConditionalExpression(
            loc('18-35'),
            ReferenceExpression(loc('21'), ident('c')),
            ReferenceExpression(loc('28'), ident('d')),
            ReferenceExpression(loc('35'), ident('e'))
          )
        )
      ),
    },
    {
      source: 'if a then if b then c else d else e',
      result: Ok(
        ConditionalExpression(
          loc('1-35'),
          ReferenceExpression(loc('4'), ident('a')),
          ConditionalExpression(
            loc('11-28'),
            ReferenceExpression(loc('14'), ident('b')),
            ReferenceExpression(loc('21'), ident('c')),
            ReferenceExpression(loc('28'), ident('d'))
          ),
          ReferenceExpression(loc('35'), ident('e'))
        )
      ),
    },
    {
      source: 'if if a then b else c then d else e',
      result: Ok(
        ConditionalExpression(
          loc('1-35'),
          ConditionalExpression(
            loc('4-21'),
            ReferenceExpression(loc('7'), ident('a')),
            ReferenceExpression(loc('14'), ident('b')),
            ReferenceExpression(loc('21'), ident('c'))
          ),
          ReferenceExpression(loc('28'), ident('d')),
          ReferenceExpression(loc('35'), ident('e'))
        )
      ),
    },
    {
      source: 'a + if x then y else z + b',
      result: Err(
        UnexpectedTokenError(GlyphToken(loc('3'), Glyph.Plus), ExpectedEnd)
      ),
    },
  ].forEach(({source, result}) => {
    test(source.replace(/\n/g, '\\n'), () => {
      expect(parseExpression(lex(source))).toEqual(result);
    });
  });
});

describe('pattern', () => {
  const cases = [
    {
      source: 'foo',
      result: Ok(BindingPattern(loc('1-3'), ident('foo'))),
    },
    {
      source: 'in',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('1-2'), 'in' as Identifier),
          ExpectedPattern
        )
      ),
    },
    {source: '_', result: Ok(HolePattern(loc('1')))},
    {
      source: '_x',
      result: Ok(BindingPattern(loc('1-2'), ident('_x'))),
    },
    {
      source: '()',
      result: Ok(UnitPattern(loc('1-2'))),
    },
    {
      source: '(foo)',
      result: Ok(
        WrappedPattern(
          loc('1-5'),
          BindingPattern(loc('2-4'), ident('foo')),
          undefined
        )
      ),
    },
    {
      source: '(a, b)',
      result: Ok(
        TuplePattern(loc('1-6'), [
          TuplePatternElement(BindingPattern(loc('2'), ident('a')), undefined),
          TuplePatternElement(BindingPattern(loc('5'), ident('b')), undefined),
        ])
      ),
    },
    {
      source: '(a, b, c, d)',
      result: Ok(
        TuplePattern(loc('1-12'), [
          TuplePatternElement(BindingPattern(loc('2'), ident('a')), undefined),
          TuplePatternElement(BindingPattern(loc('5'), ident('b')), undefined),
          TuplePatternElement(BindingPattern(loc('8'), ident('c')), undefined),
          TuplePatternElement(BindingPattern(loc('11'), ident('d')), undefined),
        ])
      ),
    },
    {
      source: '(,)',
      result: Err(
        UnexpectedTokenError(GlyphToken(loc('2'), Glyph.Comma), ExpectedPattern)
      ),
    },
    {
      source: '(foo,)',
      result: Ok(
        WrappedPattern(
          loc('1-6'),
          BindingPattern(loc('2-4'), ident('foo')),
          undefined
        )
      ),
    },
    {
      source: '(a, b,)',
      result: Ok(
        TuplePattern(loc('1-7'), [
          TuplePatternElement(BindingPattern(loc('2'), ident('a')), undefined),
          TuplePatternElement(BindingPattern(loc('5'), ident('b')), undefined),
        ])
      ),
    },
    {
      source: '(a, b, c, d,)',
      result: Ok(
        TuplePattern(loc('1-13'), [
          TuplePatternElement(BindingPattern(loc('2'), ident('a')), undefined),
          TuplePatternElement(BindingPattern(loc('5'), ident('b')), undefined),
          TuplePatternElement(BindingPattern(loc('8'), ident('c')), undefined),
          TuplePatternElement(BindingPattern(loc('11'), ident('d')), undefined),
        ])
      ),
    },
    {
      source: '(x:)',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('4'), Glyph.ParenRight),
          ExpectedType
        )
      ),
    },
    {
      source: '(x: T)',
      result: Ok(
        WrappedPattern(
          loc('1-6'),
          BindingPattern(loc('2'), ident('x')),
          ReferenceType(loc('5'), ident('T'))
        )
      ),
    },
    {
      source: '(a: A, b: B)',
      result: Ok(
        TuplePattern(loc('1-12'), [
          TuplePatternElement(
            BindingPattern(loc('2'), ident('a')),
            ReferenceType(loc('5'), ident('A'))
          ),
          TuplePatternElement(
            BindingPattern(loc('8'), ident('b')),
            ReferenceType(loc('11'), ident('B'))
          ),
        ])
      ),
    },
    {
      source: '(a: A, b: B, c: C, d: D)',
      result: Ok(
        TuplePattern(loc('1-24'), [
          TuplePatternElement(
            BindingPattern(loc('2'), ident('a')),
            ReferenceType(loc('5'), ident('A'))
          ),
          TuplePatternElement(
            BindingPattern(loc('8'), ident('b')),
            ReferenceType(loc('11'), ident('B'))
          ),
          TuplePatternElement(
            BindingPattern(loc('14'), ident('c')),
            ReferenceType(loc('17'), ident('C'))
          ),
          TuplePatternElement(
            BindingPattern(loc('20'), ident('d')),
            ReferenceType(loc('23'), ident('D'))
          ),
        ])
      ),
    },
    {
      source: '(x: T,)',
      result: Ok(
        WrappedPattern(
          loc('1-7'),
          BindingPattern(loc('2'), ident('x')),
          ReferenceType(loc('5'), ident('T'))
        )
      ),
    },
    {
      source: '(a: A, b: B,)',
      result: Ok(
        TuplePattern(loc('1-13'), [
          TuplePatternElement(
            BindingPattern(loc('2'), ident('a')),
            ReferenceType(loc('5'), ident('A'))
          ),
          TuplePatternElement(
            BindingPattern(loc('8'), ident('b')),
            ReferenceType(loc('11'), ident('B'))
          ),
        ])
      ),
    },
    {
      source: '{}',
      result: Ok(RecordPattern(loc('1-2'), [])),
    },
    {
      source: '{ foo }',
      result: Ok(
        RecordPattern(loc('1-7'), [
          RecordPatternProperty(
            Name(loc('3-5'), ident('foo')),
            BindingPattern(loc('3-5'), ident('foo')),
            undefined
          ),
        ])
      ),
    },
    {
      source: '{ foo, bar }',
      result: Ok(
        RecordPattern(loc('1-12'), [
          RecordPatternProperty(
            Name(loc('3-5'), ident('foo')),
            BindingPattern(loc('3-5'), ident('foo')),
            undefined
          ),
          RecordPatternProperty(
            Name(loc('8-10'), ident('bar')),
            BindingPattern(loc('8-10'), ident('bar')),
            undefined
          ),
        ])
      ),
    },
    {
      source: '{ foo, bar, qux, lit }',
      result: Ok(
        RecordPattern(loc('1-22'), [
          RecordPatternProperty(
            Name(loc('3-5'), ident('foo')),
            BindingPattern(loc('3-5'), ident('foo')),
            undefined
          ),
          RecordPatternProperty(
            Name(loc('8-10'), ident('bar')),
            BindingPattern(loc('8-10'), ident('bar')),
            undefined
          ),
          RecordPatternProperty(
            Name(loc('13-15'), ident('qux')),
            BindingPattern(loc('13-15'), ident('qux')),
            undefined
          ),
          RecordPatternProperty(
            Name(loc('18-20'), ident('lit')),
            BindingPattern(loc('18-20'), ident('lit')),
            undefined
          ),
        ])
      ),
    },
    {
      source: '{ foo: T }',
      result: Ok(
        RecordPattern(loc('1-10'), [
          RecordPatternProperty(
            Name(loc('3-5'), ident('foo')),
            BindingPattern(loc('3-5'), ident('foo')),
            ReferenceType(loc('8'), ident('T'))
          ),
        ])
      ),
    },
    {
      source: '{ foo: T, bar: U }',
      result: Ok(
        RecordPattern(loc('1-18'), [
          RecordPatternProperty(
            Name(loc('3-5'), ident('foo')),
            BindingPattern(loc('3-5'), ident('foo')),
            ReferenceType(loc('8'), ident('T'))
          ),
          RecordPatternProperty(
            Name(loc('11-13'), ident('bar')),
            BindingPattern(loc('11-13'), ident('bar')),
            ReferenceType(loc('16'), ident('U'))
          ),
        ])
      ),
    },
    {
      source: '{ foo: T, bar: U, qux: V, lit: W }',
      result: Ok(
        RecordPattern(loc('1-34'), [
          RecordPatternProperty(
            Name(loc('3-5'), ident('foo')),
            BindingPattern(loc('3-5'), ident('foo')),
            ReferenceType(loc('8'), ident('T'))
          ),
          RecordPatternProperty(
            Name(loc('11-13'), ident('bar')),
            BindingPattern(loc('11-13'), ident('bar')),
            ReferenceType(loc('16'), ident('U'))
          ),
          RecordPatternProperty(
            Name(loc('19-21'), ident('qux')),
            BindingPattern(loc('19-21'), ident('qux')),
            ReferenceType(loc('24'), ident('V'))
          ),
          RecordPatternProperty(
            Name(loc('27-29'), ident('lit')),
            BindingPattern(loc('27-29'), ident('lit')),
            ReferenceType(loc('32'), ident('W'))
          ),
        ])
      ),
    },
    {
      source: '{ foo = foo2 }',
      result: Ok(
        RecordPattern(loc('1-14'), [
          RecordPatternProperty(
            Name(loc('3-5'), ident('foo')),
            BindingPattern(loc('9-12'), ident('foo2')),
            undefined
          ),
        ])
      ),
    },
    {
      source: '{ foo = foo2, bar = bar2 }',
      result: Ok(
        RecordPattern(loc('1-26'), [
          RecordPatternProperty(
            Name(loc('3-5'), ident('foo')),
            BindingPattern(loc('9-12'), ident('foo2')),
            undefined
          ),
          RecordPatternProperty(
            Name(loc('15-17'), ident('bar')),
            BindingPattern(loc('21-24'), ident('bar2')),
            undefined
          ),
        ])
      ),
    },
    {
      source: '{ foo: T = x }',
      result: Ok(
        RecordPattern(loc('1-14'), [
          RecordPatternProperty(
            Name(loc('3-5'), ident('foo')),
            BindingPattern(loc('12'), ident('x')),
            ReferenceType(loc('8'), ident('T'))
          ),
        ])
      ),
    },
    {
      source: '{ foo?: T }',
      result: Ok(
        RecordPattern(loc('1-11'), [
          RecordPatternProperty(
            Name(loc('3-5'), ident('foo')),
            BindingPattern(loc('3-5'), ident('foo')),
            ReferenceType(loc('9'), ident('T')),
            {optional: true}
          ),
        ])
      ),
    },
    {
      source: '{ foo? }',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('8'), Glyph.BraceRight),
          ExpectedGlyph(Glyph.Colon)
        )
      ),
    },
    {
      source: "{ in = in' }",
      result: Ok(
        RecordPattern(loc('1-12'), [
          RecordPatternProperty(
            Name(loc('3-4'), 'in' as BindingIdentifier),
            BindingPattern(loc('8-10'), ident("in'")),
            undefined
          ),
        ])
      ),
    },
    {
      source: '{ in }',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('3-4'), 'in' as Identifier),
          ExpectedBindingIdentifier
        )
      ),
    },
    {
      source: '[]',
      result: Ok(ListPattern(loc('1-2'), [])),
    },
    {
      source: '[a]',
      result: Ok(
        ListPattern(loc('1-3'), [BindingPattern(loc('2'), ident('a'))])
      ),
    },
    {
      source: '[a, b]',
      result: Ok(
        ListPattern(loc('1-6'), [
          BindingPattern(loc('2'), ident('a')),
          BindingPattern(loc('5'), ident('b')),
        ])
      ),
    },
    {
      source: '[a, b, c, d]',
      result: Ok(
        ListPattern(loc('1-12'), [
          BindingPattern(loc('2'), ident('a')),
          BindingPattern(loc('5'), ident('b')),
          BindingPattern(loc('8'), ident('c')),
          BindingPattern(loc('11'), ident('d')),
        ])
      ),
    },
    {
      source: 'a.b',
      result: Ok(
        QualifiedPattern(loc('1-3'), [
          Name(loc('1'), ident('a')),
          Name(loc('3'), ident('b')),
        ])
      ),
    },
    {
      source: 'a.b.c',
      result: Ok(
        QualifiedPattern(loc('1-5'), [
          Name(loc('1'), ident('a')),
          Name(loc('3'), ident('b')),
          Name(loc('5'), ident('c')),
        ])
      ),
    },
    {
      source: 'a.b.c.d',
      result: Ok(
        QualifiedPattern(loc('1-7'), [
          Name(loc('1'), ident('a')),
          Name(loc('3'), ident('b')),
          Name(loc('5'), ident('c')),
          Name(loc('7'), ident('d')),
        ])
      ),
    },
    {
      source: 'in.yay',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('1-2'), 'in' as Identifier),
          ExpectedPattern
        )
      ),
    },
    {
      source: 'yay.in',
      result: Ok(
        QualifiedPattern(loc('1-6'), [
          Name(loc('1-3'), ident('yay')),
          Name(loc('5-6'), 'in' as BindingIdentifier),
        ])
      ),
    },
    {
      source: 'foo\n()',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('2:1'), Glyph.ParenLeft),
          ExpectedEnd
        )
      ),
    },
    {
      source: 'a()',
      result: Ok(
        DeconstructPattern(loc('1-3'), [Name(loc('1'), ident('a'))], [])
      ),
    },
    {
      source: 'a.b()',
      result: Ok(
        DeconstructPattern(
          loc('1-5'),
          [Name(loc('1'), ident('a')), Name(loc('3'), ident('b'))],
          []
        )
      ),
    },
    {
      source: 'a.b.c.d()',
      result: Ok(
        DeconstructPattern(
          loc('1-9'),
          [
            Name(loc('1'), ident('a')),
            Name(loc('3'), ident('b')),
            Name(loc('5'), ident('c')),
            Name(loc('7'), ident('d')),
          ],
          []
        )
      ),
    },
    {
      source: 'T(a)',
      result: Ok(
        DeconstructPattern(
          loc('1-4'),
          [Name(loc('1'), ident('T'))],
          [BindingPattern(loc('3'), ident('a'))]
        )
      ),
    },
    {
      source: 'T(a, b)',
      result: Ok(
        DeconstructPattern(
          loc('1-7'),
          [Name(loc('1'), ident('T'))],
          [
            BindingPattern(loc('3'), ident('a')),
            BindingPattern(loc('6'), ident('b')),
          ]
        )
      ),
    },
    {
      source: 'T(a, b, c, d)',
      result: Ok(
        DeconstructPattern(
          loc('1-13'),
          [Name(loc('1'), ident('T'))],
          [
            BindingPattern(loc('3'), ident('a')),
            BindingPattern(loc('6'), ident('b')),
            BindingPattern(loc('9'), ident('c')),
            BindingPattern(loc('12'), ident('d')),
          ]
        )
      ),
    },
    {
      source: 'in()',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('1-2'), 'in' as Identifier),
          ExpectedPattern
        )
      ),
    },
    {
      source: 'in.yay()',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('1-2'), 'in' as Identifier),
          ExpectedPattern
        )
      ),
    },
    {
      source: 'yay.in()',
      result: Ok(
        DeconstructPattern(
          loc('1-8'),
          [
            Name(loc('1-3'), ident('yay')),
            Name(loc('5-6'), 'in' as BindingIdentifier),
          ],
          []
        )
      ),
    },
    {
      source: 'x\nis ()',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('2:1-2:2'), ident('is')),
          ExpectedEnd
        )
      ),
    },
    {
      source: 'x is ()',
      result: Ok(
        AliasPattern(
          loc('1-7'),
          BindingName(loc('1'), ident('x')),
          UnitPattern(loc('6-7'))
        )
      ),
    },
    {
      source: 'in is ()',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('1-2'), 'in' as Identifier),
          ExpectedPattern
        )
      ),
    },
    {
      source: 'x\nis ()',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('2:1-2:2'), ident('is')),
          ExpectedEnd
        )
      ),
    },
  ];

  cases.forEach(({source, result}) => {
    test(source.replace(/\n/g, '\\n'), () => {
      expect(parsePattern(lex(source))).toEqual(result);
    });
  });

  describe('from expression', () => {
    cases.forEach(({source, result: expectedResult}) => {
      test(source.replace(/\n/g, '\\n'), () => {
        const lexer = lex(source);
        const result = parseExpression(lexer);
        switch (result.type) {
          case ResultType.Ok: {
            const pattern = expressionIntoPattern(lexer.next(), result.value);
            expect(Ok(pattern)).toEqual(expectedResult);
            break;
          }
          case ResultType.Err: {
            const error =
              result.value.type === ParserErrorType.UnexpectedToken
                ? UnexpectedTokenError(
                    result.value.unexpected,
                    result.value.expected === ExpectedExpression
                      ? ExpectedPattern
                      : result.value.expected
                  )
                : result.value;
            expect(Err(error)).toEqual(expectedResult);
            break;
          }
        }
      });
    });
  });
});

describe('comma list', () => {
  [
    {source: '()', result: Ok([])},
    {source: '(foo)', result: Ok(['foo'])},
    {source: '(foo, bar)', result: Ok(['foo', 'bar'])},
    {
      source: '(foo, bar, qux, lit)',
      result: Ok(['foo', 'bar', 'qux', 'lit']),
    },
    {
      source: '(,)',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('2'), Glyph.Comma),
          ExpectedIdentifier
        )
      ),
    },
    {source: '(foo,)', result: Ok(['foo'])},
    {source: '(foo, bar,)', result: Ok(['foo', 'bar'])},
    {
      source: '(foo, bar, qux, lit,)',
      result: Ok(['foo', 'bar', 'qux', 'lit']),
    },
    {
      source: '(%)',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('2'), Glyph.Percent),
          ExpectedIdentifier
        )
      ),
    },
    {
      source: '( % )',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('3'), Glyph.Percent),
          ExpectedIdentifier
        )
      ),
    },
    {
      source: '(foo bar)',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('6-8'), ident('bar')),
          ExpectedGlyph(Glyph.Comma)
        )
      ),
    },
    {
      source: '(foo, bar qux)',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('11-13'), ident('qux')),
          ExpectedGlyph(Glyph.Comma)
        )
      ),
    },
    {
      source: '(foo bar qux)',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('6-8'), ident('bar')),
          ExpectedGlyph(Glyph.Comma)
        )
      ),
    },
    {
      source: '(foo,, bar)',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('6'), Glyph.Comma),
          ExpectedIdentifier
        )
      ),
    },
    {
      source: '(foo; bar)',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('5'), Glyph.Semicolon),
          ExpectedGlyph(Glyph.Comma)
        )
      ),
    },
    {
      source: '(foo;; bar)',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('5'), Glyph.Semicolon),
          ExpectedGlyph(Glyph.Comma)
        )
      ),
    },
    {
      source: '(foo, bar;)',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('10'), Glyph.Semicolon),
          ExpectedGlyph(Glyph.Comma)
        )
      ),
    },
    {
      source: '(',
      result: Err(UnexpectedTokenError(EndToken(loc('2')), ExpectedIdentifier)),
    },
    {
      source: '(foo',
      result: Err(
        UnexpectedTokenError(EndToken(loc('5')), ExpectedGlyph(Glyph.Comma))
      ),
    },
  ].forEach(({source, result}) => {
    test(source, () => {
      expect(parseCommaListTest(lex(source))).toEqual(result);
    });
  });
});

describe('line separator list', () => {
  [
    {
      source: '()',
      result: Ok([]),
    },
    {
      source: '(foo)',
      result: Ok(['foo']),
    },
    {
      source: '(foo; bar)',
      result: Ok(['foo', 'bar']),
    },
    {
      source: '(foo; bar; qux; lit)',
      result: Ok(['foo', 'bar', 'qux', 'lit']),
    },
    {
      source: '(;)',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('2'), Glyph.Semicolon),
          ExpectedIdentifier
        )
      ),
    },
    {
      source: '(foo;)',
      result: Ok(['foo']),
    },
    {
      source: '(foo; bar;)',
      result: Ok(['foo', 'bar']),
    },
    {
      source: '(foo; bar; qux; lit;)',
      result: Ok(['foo', 'bar', 'qux', 'lit']),
    },
    {
      source: '(%)',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('2'), Glyph.Percent),
          ExpectedIdentifier
        )
      ),
    },
    {
      source: '( % )',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('3'), Glyph.Percent),
          ExpectedIdentifier
        )
      ),
    },
    {
      source: '(foo bar)',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('6-8'), ident('bar')),
          ExpectedLineSeparator
        )
      ),
    },
    {
      source: '(foo; bar qux)',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('11-13'), ident('qux')),
          ExpectedLineSeparator
        )
      ),
    },
    {
      source: '(foo bar qux)',
      result: Err(
        UnexpectedTokenError(
          IdentifierToken(loc('6-8'), ident('bar')),
          ExpectedLineSeparator
        )
      ),
    },
    {
      source: '(foo;; bar)',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('6'), Glyph.Semicolon),
          ExpectedIdentifier
        )
      ),
    },
    {
      source: '(foo, bar)',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('5'), Glyph.Comma),
          ExpectedLineSeparator
        )
      ),
    },
    {
      source: '(foo,, bar)',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('5'), Glyph.Comma),
          ExpectedLineSeparator
        )
      ),
    },
    {
      source: '(foo; bar,)',
      result: Err(
        UnexpectedTokenError(
          GlyphToken(loc('10'), Glyph.Comma),
          ExpectedLineSeparator
        )
      ),
    },
    {
      source: '(',
      result: Err(UnexpectedTokenError(EndToken(loc('2')), ExpectedIdentifier)),
    },
    {
      source: '(foo',
      result: Err(
        UnexpectedTokenError(EndToken(loc('5')), ExpectedLineSeparator)
      ),
    },
    {
      source: '(\n)',
      result: Ok([]),
    },
    {
      source: '(foo\n)',
      result: Ok(['foo']),
    },
    {
      source: '(foo\nbar)',
      result: Ok(['foo', 'bar']),
    },
    {
      source: '(\n\n)',
      result: Ok([]),
    },
    {
      source: '(\nfoo\n)',
      result: Ok(['foo']),
    },
    {
      source: '(foo\n\n)',
      result: Ok(['foo']),
    },
    {
      source: '(foo\n\nbar)',
      result: Ok(['foo', 'bar']),
    },
    {
      source: '(\n  foo\n  bar\n  qux\n  lit\n)',
      result: Ok(['foo', 'bar', 'qux', 'lit']),
    },
    {
      source: '(foo;\nbar)',
      result: Ok(['foo', 'bar']),
    },
    {
      source: '(foo\n;bar)',
      result: Ok(['foo', 'bar']),
    },
  ].forEach(({source, result}) => {
    test(source.replace(/\n/g, '\\n'), () => {
      expect(parseLineSeparatorListTest(lex(source))).toEqual(result);
    });
  });
});

describe('expression into pattern', () => {
  const cases: ReadonlyArray<{
    source: string;
    result: Result<Pattern, ExpressionIntoPatternError>;
  }> = [
    {
      source: 'x',
      result: Ok(BindingPattern(loc('1'), ident('x'))),
    },
    {
      source: '_',
      result: Ok(HolePattern(loc('1'))),
    },
    {
      source: '()',
      result: Ok(UnitPattern(loc('1-2'))),
    },
    {
      source: '(a, b)',
      result: Ok(
        TuplePattern(loc('1-6'), [
          TuplePatternElement(BindingPattern(loc('2'), ident('a')), undefined),
          TuplePatternElement(BindingPattern(loc('5'), ident('b')), undefined),
        ])
      ),
    },
    {
      source: '(() -> x, y)',
      result: Err(
        ExpressionIntoPatternError(
          FunctionExpression(
            loc('2-8'),
            [],
            ReferenceExpression(loc('8'), ident('x'))
          ),
          EndToken(loc('13'))
        )
      ),
    },
    {
      source: '(y, () -> x)',
      result: Err(
        ExpressionIntoPatternError(
          FunctionExpression(
            loc('5-11'),
            [],
            ReferenceExpression(loc('11'), ident('x'))
          ),
          EndToken(loc('13'))
        )
      ),
    },
    {
      source: '{ a = b }',
      result: Ok(
        RecordPattern(loc('1-9'), [
          RecordPatternProperty(
            Name(loc('3'), ident('a')),
            BindingPattern(loc('7'), ident('b')),
            undefined
          ),
        ])
      ),
    },
    {
      source: '{ o | a = b }',
      result: Err(
        ExpressionIntoPatternError(
          ReferenceExpression(loc('3'), ident('o')),
          EndToken(loc('14'))
        )
      ),
    },
    {
      source: '{ a = () -> x }',
      result: Err(
        ExpressionIntoPatternError(
          FunctionExpression(
            loc('7-13'),
            [],
            ReferenceExpression(loc('13'), ident('x'))
          ),
          EndToken(loc('16'))
        )
      ),
    },
    {
      source: '[a, b]',
      result: Ok(
        ListPattern(loc('1-6'), [
          BindingPattern(loc('2'), ident('a')),
          BindingPattern(loc('5'), ident('b')),
        ])
      ),
    },
    {
      source: '[() -> x, y]',
      result: Err(
        ExpressionIntoPatternError(
          FunctionExpression(
            loc('2-8'),
            [],
            ReferenceExpression(loc('8'), ident('x'))
          ),
          EndToken(loc('13'))
        )
      ),
    },
    {
      source: '[y, () -> x]',
      result: Err(
        ExpressionIntoPatternError(
          FunctionExpression(
            loc('5-11'),
            [],
            ReferenceExpression(loc('11'), ident('x'))
          ),
          EndToken(loc('13'))
        )
      ),
    },
    {
      source: 'a.b.c',
      result: Ok(
        QualifiedPattern(loc('1-5'), [
          Name(loc('1'), ident('a')),
          Name(loc('3'), ident('b')),
          Name(loc('5'), ident('c')),
        ])
      ),
    },
    {
      source: '().p',
      result: Err(
        ExpressionIntoPatternError(
          UnitExpression(loc('1-2')),
          EndToken(loc('5'))
        )
      ),
    },
    {
      source: '().a.b',
      result: Err(
        ExpressionIntoPatternError(
          UnitExpression(loc('1-2')),
          EndToken(loc('7'))
        )
      ),
    },
    {
      source: 'f()',
      result: Ok(
        DeconstructPattern(loc('1-3'), [Name(loc('1'), ident('f'))], [])
      ),
    },
    {
      source: 'f<>()',
      result: Ok(
        DeconstructPattern(loc('1-5'), [Name(loc('1'), ident('f'))], [])
      ),
    },
    {
      source: 'f<T>()',
      result: Err(
        ExpressionIntoPatternError(
          CallExpression(
            loc('1-6'),
            ReferenceExpression(loc('1'), ident('f')),
            [ReferenceType(loc('3'), ident('T'))],
            []
          ),
          EndToken(loc('7'))
        )
      ),
    },
    {
      source: '()()',
      result: Err(
        ExpressionIntoPatternError(
          UnitExpression(loc('1-2')),
          EndToken(loc('5'))
        )
      ),
    },
    {
      source: '().p()',
      result: Err(
        ExpressionIntoPatternError(
          UnitExpression(loc('1-2')),
          EndToken(loc('7'))
        )
      ),
    },
    {
      source: 'f(() -> x)',
      result: Err(
        ExpressionIntoPatternError(
          FunctionExpression(
            loc('3-9'),
            [],
            ReferenceExpression(loc('9'), ident('x'))
          ),
          EndToken(loc('11'))
        )
      ),
    },
    {
      source: 'x is ()',
      result: Ok(
        AliasPattern(
          loc('1-7'),
          BindingName(loc('1'), ident('x')),
          UnitPattern(loc('6-7'))
        )
      ),
    },
    {
      source: '() is ()',
      result: Err(
        ExpressionIntoPatternError(
          UnitExpression(loc('1-2')),
          EndToken(loc('9'))
        )
      ),
    },
    {
      source: '(x)',
      result: Ok(
        WrappedPattern(
          loc('1-3'),
          BindingPattern(loc('2'), ident('x')),
          undefined
        )
      ),
    },
    {
      source: '(() -> x)',
      result: Err(
        ExpressionIntoPatternError(
          FunctionExpression(
            loc('2-8'),
            [],
            ReferenceExpression(loc('8'), ident('x'))
          ),
          EndToken(loc('10'))
        )
      ),
    },
  ];

  cases.forEach(({source, result}) => {
    test(source, () => {
      const lexer = lex(source);
      const expression = parseExpression(lexer);
      if (expression.type !== ResultType.Ok) {
        throw new Error('Could not parse expression.');
      }
      let pattern: Result<Pattern, unknown>;
      try {
        pattern = Ok(expressionIntoPattern(lexer.next(), expression.value));
      } catch (error) {
        pattern = Err(error);
      }
      expect(pattern).toEqual(result);
    });
  });
});
