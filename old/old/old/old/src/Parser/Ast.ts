import {ReadonlyArray1, ReadonlyArray2} from '../Utils/ArrayN';

import {BindingIdentifier, Identifier} from './Identifier';
import {Loc} from './Loc';

export type File = {
  readonly declarations: ReadonlyArray<Declaration>;
};

export function File(declarations: ReadonlyArray<Declaration>): File {
  return {declarations};
}

export const enum Access {
  Public = 'Public',
  Private = 'Private',
  Protected = 'Protected',
}

export interface Name {
  readonly loc: Loc;
  readonly identifier: Identifier;
}

export function Name(loc: Loc, identifier: Identifier): Name {
  return {loc, identifier};
}

export interface BindingName extends Name {
  readonly identifier: BindingIdentifier;
}

export function BindingName(
  loc: Loc,
  identifier: BindingIdentifier
): BindingName {
  return {loc, identifier};
}

export type Declaration =
  | TypeDeclaration
  | FunctionDeclaration
  | ClassDeclaration
  | InterfaceDeclaration;

export const enum DeclarationKind {
  Type = 'Type',
  Function = 'Function',
  Class = 'Class',
  Interface = 'Interface',
}

export interface NamedDeclaration {
  readonly access: Access;
  readonly name: Name;
}

export interface TypeDeclaration extends NamedDeclaration {
  readonly kind: DeclarationKind.Type;
  readonly typeParameters: ReadonlyArray<TypeParameter>;
  readonly value: Type;
}

export function TypeDeclaration(
  access: Access,
  name: Name,
  typeParameters: ReadonlyArray<TypeParameter>,
  value: Type
): TypeDeclaration {
  return {kind: DeclarationKind.Type, access, name, typeParameters, value};
}

export interface Function {
  readonly typeParameters: ReadonlyArray<TypeParameter>;
  readonly parameters: ReadonlyArray<FunctionParameter>;
  readonly return: Type | undefined;
  readonly body: Expression;
}

export interface FunctionWithOptionalBody {
  readonly typeParameters: ReadonlyArray<TypeParameter>;
  readonly parameters: ReadonlyArray<FunctionParameter>;
  readonly return: Type | undefined;
  readonly body: Expression | undefined;
}

export interface FunctionDeclaration extends Function, NamedDeclaration {
  readonly kind: DeclarationKind.Function;
}

export function FunctionDeclaration(
  access: Access,
  name: Name,
  typeParameters: ReadonlyArray<TypeParameter>,
  parameters: ReadonlyArray<FunctionParameter>,
  ret: Type | undefined,
  body: Expression
): FunctionDeclaration {
  return {
    kind: DeclarationKind.Function,
    access,
    name,
    typeParameters,
    parameters,
    return: ret,
    body,
  };
}

export type FunctionParameter = {
  readonly binding: Pattern;
  readonly annotation: Type | undefined;
};

export function FunctionParameter(
  binding: Pattern,
  annotation: Type | undefined = undefined
): FunctionParameter {
  return {binding, annotation};
}

/**
 * Base classes and concrete classes share a parser AST node. We assert that
 * base classes and concrete classes are well formed in our checking phase.
 */
export interface ClassDeclaration extends NamedDeclaration {
  readonly kind: DeclarationKind.Class;
  readonly base: boolean;
  readonly unsealed: boolean;
  readonly typeParameters: ReadonlyArray<TypeParameter>;
  readonly parameters: ReadonlyArray<FunctionParameter>;
  readonly extends: Type | undefined;
  readonly implements: ReadonlyArray<ImplementsDeclaration>;
  readonly body: ReadonlyArray<ClassMember>;
}

export function ClassDeclaration(data: {
  access: Access;
  name: Name;
  base: boolean;
  unsealed: boolean;
  typeParameters: ReadonlyArray<TypeParameter>;
  parameters: ReadonlyArray<FunctionParameter>;
  extends: Type | undefined;
  implements: ReadonlyArray<ImplementsDeclaration>;
  body: ReadonlyArray<ClassMember>;
}): ClassDeclaration {
  return {
    kind: DeclarationKind.Class,
    access: data.access,
    name: data.name,
    base: data.base,
    unsealed: data.unsealed,
    typeParameters: data.typeParameters,
    parameters: data.parameters,
    extends: data.extends,
    implements: data.implements,
    body: data.body,
  };
}

export type ClassMember = ClassMethod;

export interface ClassMethod extends FunctionWithOptionalBody {
  readonly access: Access | undefined;
  readonly base: boolean;
  readonly name: Name;
}

export function ClassMethod({
  access,
  base,
  name,
  typeParameters,
  parameters,
  return: ret,
  body,
}: {
  access: Access | undefined;
  base: boolean;
  name: Name;
  typeParameters: ReadonlyArray<TypeParameter>;
  parameters: ReadonlyArray<FunctionParameter>;
  return: Type | undefined;
  body: Expression | undefined;
}): ClassMethod {
  return {
    access,
    base,
    name,
    typeParameters,
    parameters,
    return: ret,
    body,
  };
}

export type ImplementsDeclaration = {
  readonly type: Type;
  readonly constrain: ReadonlyArray<TypeParameter>;
};

export function ImplementsDeclaration(
  type: Type,
  constrain: ReadonlyArray<TypeParameter> = []
): ImplementsDeclaration {
  return {type, constrain};
}

export interface InterfaceDeclaration extends NamedDeclaration {
  readonly kind: DeclarationKind.Interface;
  readonly typeParameters: ReadonlyArray<TypeParameter>;
  readonly extends: ReadonlyArray<ImplementsDeclaration>;
  readonly body: ReadonlyArray<InterfaceMember>;
}

export function InterfaceDeclaration(data: {
  access: Access;
  name: Name;
  typeParameters: ReadonlyArray<TypeParameter>;
  extends: ReadonlyArray<ImplementsDeclaration>;
  body: ReadonlyArray<InterfaceMember>;
}): InterfaceDeclaration {
  return {
    kind: DeclarationKind.Interface,
    access: data.access,
    name: data.name,
    typeParameters: data.typeParameters,
    extends: data.extends,
    body: data.body,
  };
}

export type InterfaceMember = InterfaceMethod;

export interface InterfaceMethod extends FunctionWithOptionalBody {
  readonly access: Access | undefined;
  readonly name: Name;
}

export function InterfaceMethod({
  access,
  name,
  typeParameters,
  parameters,
  return: ret,
  body,
}: {
  access: Access | undefined;
  name: Name;
  typeParameters: ReadonlyArray<TypeParameter>;
  parameters: ReadonlyArray<FunctionParameter>;
  return: Type | undefined;
  body: Expression | undefined;
}): InterfaceMethod {
  return {
    access,
    name,
    typeParameters,
    parameters,
    return: ret,
    body,
  };
}

/**
 * Any node in our AST.
 */
export interface Node {
  readonly loc: Loc;
}

export type Type =
  | ReferenceType
  | UnitType
  | TupleType
  | RecordType
  | FunctionType
  | MemberType
  | GenericType
  | WrappedType;

export const enum TypeKind {
  Reference = 'Reference',
  Unit = 'Unit',
  Tuple = 'Tuple',
  Record = 'Record',
  Function = 'Function',
  Member = 'Member',
  Generic = 'Generic',
  Wrapped = 'Wrapped',
}

export interface ReferenceType extends Node {
  readonly kind: TypeKind.Reference;
  readonly identifier: BindingIdentifier;
}

export function ReferenceType(
  loc: Loc,
  identifier: BindingIdentifier
): ReferenceType {
  return {kind: TypeKind.Reference, loc, identifier};
}

export interface UnitType extends Node {
  readonly kind: TypeKind.Unit;
}

export function UnitType(loc: Loc): UnitType {
  return {kind: TypeKind.Unit, loc};
}

export interface TupleType extends Node {
  readonly kind: TypeKind.Tuple;
  readonly elements: ReadonlyArray2<Type>;
}

export function TupleType(loc: Loc, elements: ReadonlyArray2<Type>): TupleType {
  return {kind: TypeKind.Tuple, loc, elements};
}

export interface RecordType extends Node {
  readonly kind: TypeKind.Record;
  readonly properties: ReadonlyArray<RecordTypeProperty>;
}

export function RecordType(
  loc: Loc,
  properties: ReadonlyArray<RecordTypeProperty>
): RecordType {
  return {kind: TypeKind.Record, loc, properties};
}

export type RecordTypeProperty = {
  readonly key: Name;
  readonly value: Type;
  readonly optional: boolean;
};

export function RecordTypeProperty(
  key: Name,
  value: Type,
  {optional = false}: {optional?: boolean} = {}
): RecordTypeProperty {
  return {key, value, optional};
}

export interface FunctionType extends Node {
  readonly kind: TypeKind.Function;
  readonly parameters: ReadonlyArray<Type>;
  readonly body: Type;
}

export function FunctionType(
  loc: Loc,
  parameters: ReadonlyArray<Type>,
  body: Type
): FunctionType {
  return {kind: TypeKind.Function, loc, parameters, body};
}

export interface MemberType extends Node {
  readonly kind: TypeKind.Member;
  readonly namespace: Type;
  readonly member: Name;
}

export function MemberType(
  loc: Loc,
  namespace: Type,
  member: Name
): MemberType {
  return {kind: TypeKind.Member, loc, namespace, member};
}

export interface GenericType extends Node {
  readonly kind: TypeKind.Generic;
  readonly callee: Type;
  readonly typeArguments: ReadonlyArray<Type>;
}

export function GenericType(
  loc: Loc,
  callee: Type,
  typeArguments: ReadonlyArray<Type>
): GenericType {
  return {kind: TypeKind.Generic, loc, callee, typeArguments};
}

export interface WrappedType extends Node {
  readonly kind: TypeKind.Wrapped;
  readonly type: Type;
}

export function WrappedType(loc: Loc, type: Type): WrappedType {
  return {kind: TypeKind.Wrapped, loc, type};
}

export type TypeParameter = {
  readonly name: Name;
  readonly bounds: ReadonlyArray<Type>;
};

export function TypeParameter(
  name: Name,
  bounds: ReadonlyArray<Type> = []
): TypeParameter {
  return {name, bounds};
}

export type Statement =
  | ExpressionStatement
  | BindingStatement
  | WhileLoopStatement
  | ForLoopStatement;

export const enum StatementKind {
  Expression = 'Expression',
  Binding = 'Binding',
  Assignment = 'Assignment',
  WhileLoop = 'WhileLoop',
  ForLoop = 'ForLoop',
}

export interface ExpressionStatement {
  readonly kind: StatementKind.Expression;
  readonly expression: Expression;
}

export function ExpressionStatement(
  expression: Expression
): ExpressionStatement {
  return {kind: StatementKind.Expression, expression};
}

export interface BindingStatement {
  readonly kind: StatementKind.Binding;
  readonly binding: Pattern;
  readonly type: Type | undefined;
  readonly value: Expression;
}

export function BindingStatement(
  binding: Pattern,
  type: Type | undefined,
  value: Expression
): BindingStatement {
  return {kind: StatementKind.Binding, binding, type, value};
}

export interface WhileLoopStatement {
  readonly kind: StatementKind.WhileLoop;
  readonly test: Expression;
  readonly body: Expression;
}

export function WhileLoopStatement(
  test: Expression,
  body: Expression
): WhileLoopStatement {
  return {kind: StatementKind.WhileLoop, test, body};
}

export interface ForLoopStatement {
  readonly kind: StatementKind.ForLoop;
  readonly binding: Pattern;
  readonly iterable: Expression;
  readonly body: Expression;
}

export function ForLoopStatement(
  binding: Pattern,
  iterable: Expression,
  body: Expression
): ForLoopStatement {
  return {kind: StatementKind.ForLoop, binding, iterable, body};
}

export type Expression =
  | ReferenceExpression
  | HoleExpression
  | UnitExpression
  | TupleExpression
  | RecordExpression
  | ListExpression
  | MemberExpression
  | CallExpression
  | FunctionExpression
  | ConditionalExpression
  | MatchExpression
  | PatternExpression
  | ReturnExpression
  | BreakExpression
  | ContinueExpression
  | LoopExpression
  | LogicalExpression
  | BinaryExpression
  | UnaryExpression
  | BlockExpression
  | WrappedExpression;

export const enum ExpressionKind {
  Reference = 'Reference',
  Hole = 'Hole',
  Unit = 'Unit',
  Tuple = 'Tuple',
  Record = 'Record',
  List = 'List',
  Member = 'Member',
  Call = 'Call',
  Function = 'Function',
  Conditional = 'Conditional',
  Match = 'Match',
  Pattern = 'Pattern',
  Return = 'Return',
  Break = 'Break',
  Continue = 'Continue',
  Loop = 'Loop',
  Logical = 'Logical',
  Binary = 'Binary',
  Unary = 'Unary',
  Block = 'Block',
  Wrapped = 'Wrapped',
}

export interface ReferenceExpression extends Node {
  readonly kind: ExpressionKind.Reference;
  readonly identifier: BindingIdentifier;
}

export function ReferenceExpression(
  loc: Loc,
  identifier: BindingIdentifier
): ReferenceExpression {
  return {kind: ExpressionKind.Reference, loc, identifier};
}

export interface HoleExpression extends Node {
  readonly kind: ExpressionKind.Hole;
}

export function HoleExpression(loc: Loc): HoleExpression {
  return {kind: ExpressionKind.Hole, loc};
}

export interface UnitExpression extends Node {
  readonly kind: ExpressionKind.Unit;
}

export function UnitExpression(loc: Loc): UnitExpression {
  return {kind: ExpressionKind.Unit, loc};
}

export interface TupleExpression extends Node {
  readonly kind: ExpressionKind.Tuple;
  readonly elements: ReadonlyArray2<TupleExpressionElement>;
}

export function TupleExpression(
  loc: Loc,
  elements: ReadonlyArray2<TupleExpressionElement>
): TupleExpression {
  return {kind: ExpressionKind.Tuple, loc, elements};
}

export type TupleExpressionElement = {
  readonly expression: Expression;
  readonly type: Type | undefined;
};

export function TupleExpressionElement(
  expression: Expression,
  type: Type | undefined = undefined
): TupleExpressionElement {
  return {expression, type};
}

export interface RecordExpression extends Node {
  readonly kind: ExpressionKind.Record;
  readonly extension: Expression | undefined;
  readonly properties: ReadonlyArray<RecordExpressionProperty>;
}

export function RecordExpression(
  loc: Loc,
  extension: Expression | undefined,
  properties: ReadonlyArray<RecordExpressionProperty>
): RecordExpression {
  return {kind: ExpressionKind.Record, loc, extension, properties};
}

export type RecordExpressionProperty = {
  readonly key: Name;
  readonly value: Expression;
  readonly type: Type | undefined;
  readonly optional: boolean;
};

export function RecordExpressionProperty(
  key: Name,
  value: Expression,
  type: Type | undefined,
  {optional = false}: {optional?: boolean} = {}
): RecordExpressionProperty {
  return {key, value, type, optional};
}

export interface ListExpression extends Node {
  readonly kind: ExpressionKind.List;
  readonly items: ReadonlyArray<Expression>;
}

export function ListExpression(
  loc: Loc,
  items: ReadonlyArray<Expression>
): ListExpression {
  return {kind: ExpressionKind.List, loc, items};
}

export interface MemberExpression extends Node {
  readonly kind: ExpressionKind.Member;
  readonly namespace: Expression;
  readonly member: Name;
}

export function MemberExpression(
  loc: Loc,
  namespace: Expression,
  member: Name
): MemberExpression {
  return {kind: ExpressionKind.Member, loc, namespace, member};
}

export interface CallExpression extends Node {
  readonly kind: ExpressionKind.Call;
  readonly callee: Expression;
  readonly arguments: ReadonlyArray<Expression>;
}

export function CallExpression(
  loc: Loc,
  callee: Expression,
  args: ReadonlyArray<Expression>
): CallExpression {
  return {
    kind: ExpressionKind.Call,
    loc,
    callee,
    arguments: args,
  };
}

export interface FunctionExpression extends Function, Node {
  readonly kind: ExpressionKind.Function;
}

export function FunctionExpression(
  loc: Loc,
  typeParameters: ReadonlyArray<TypeParameter>,
  parameters: ReadonlyArray<FunctionParameter>,
  ret: Type | undefined,
  body: Expression
): FunctionExpression {
  return {
    kind: ExpressionKind.Function,
    loc,
    typeParameters,
    parameters,
    return: ret,
    body,
  };
}

export interface ConditionalExpression extends Node {
  readonly kind: ExpressionKind.Conditional;
  readonly test: Expression;
  readonly consequent: Expression;
  readonly alternate: Expression | undefined;
}

export function ConditionalExpression(
  loc: Loc,
  test: Expression,
  consequent: Expression,
  alternate: Expression | undefined
): ConditionalExpression {
  return {kind: ExpressionKind.Conditional, loc, test, consequent, alternate};
}

export interface MatchExpression extends Node {
  readonly kind: ExpressionKind.Match;
  readonly test: Expression;
  readonly cases: ReadonlyArray<MatchCase>;
}

export function MatchExpression(
  loc: Loc,
  test: Expression,
  cases: ReadonlyArray<MatchCase>
): MatchExpression {
  return {kind: ExpressionKind.Match, loc, test, cases};
}

export type MatchCase = {
  readonly binding: ReadonlyArray1<Pattern>;
  readonly test: Expression | undefined;
  readonly body: Expression;
};

export function MatchCase(
  binding: ReadonlyArray1<Pattern>,
  test: Expression | undefined,
  body: Expression
): MatchCase {
  return {binding, test, body};
}

export interface PatternExpression extends Node {
  readonly kind: ExpressionKind.Pattern;
  readonly left: Expression;
  readonly right: Pattern;
}

export function PatternExpression(
  loc: Loc,
  left: Expression,
  right: Pattern
): PatternExpression {
  return {kind: ExpressionKind.Pattern, loc, left, right};
}

export interface ReturnExpression extends Node {
  readonly kind: ExpressionKind.Return;
  readonly argument: Expression | undefined;
}

export function ReturnExpression(
  loc: Loc,
  argument: Expression | undefined
): ReturnExpression {
  return {kind: ExpressionKind.Return, loc, argument};
}

export interface BreakExpression extends Node {
  readonly kind: ExpressionKind.Break;
  readonly argument: Expression | undefined;
}

export function BreakExpression(
  loc: Loc,
  argument: Expression | undefined
): BreakExpression {
  return {kind: ExpressionKind.Break, loc, argument};
}

export interface ContinueExpression extends Node {
  readonly kind: ExpressionKind.Continue;
}

export function ContinueExpression(loc: Loc): ContinueExpression {
  return {kind: ExpressionKind.Continue, loc};
}

export interface LoopExpression extends Node {
  readonly kind: ExpressionKind.Loop;
  readonly body: Expression;
}

export function LoopExpression(loc: Loc, body: Expression): LoopExpression {
  return {kind: ExpressionKind.Loop, loc, body};
}

/**
 * `LogicalExpression` is separate from `BinaryExpression` because the `right`
 * expression in `LogicalExpression` is evaluated conditionally and so deserves
 * special treatment.
 */
export interface LogicalExpression extends Node {
  readonly kind: ExpressionKind.Logical;
  readonly operator: LogicalExpressionOperator;
  readonly left: Expression;
  readonly right: Expression;
}

export function LogicalExpression(
  loc: Loc,
  operator: LogicalExpressionOperator,
  left: Expression,
  right: Expression
): LogicalExpression {
  return {kind: ExpressionKind.Logical, loc, operator, left, right};
}

export const enum LogicalExpressionOperator {
  And = '&&',
  Or = '||',
}

export interface BinaryExpression extends Node {
  readonly kind: ExpressionKind.Binary;
  readonly operator: BinaryExpressionOperator;
  readonly left: Expression;
  readonly right: Expression;
}

export function BinaryExpression(
  loc: Loc,
  operator: BinaryExpressionOperator,
  left: Expression,
  right: Expression
): BinaryExpression {
  return {kind: ExpressionKind.Binary, loc, operator, left, right};
}

export const enum BinaryExpressionOperator {
  Equal = '==',
  EqualNot = '!=',
  LessThan = '<',
  LessThanOrEqual = '<=',
  GreaterThan = '>',
  GreaterThanOrEqual = '>=',
  Add = '+',
  Subtract = '-',
  Multiply = '*',
  Divide = '/',
  Remainder = '%',
}

export interface UnaryExpression extends Node {
  readonly kind: ExpressionKind.Unary;
  readonly operator: UnaryExpressionOperator;
  readonly argument: Expression;
}

export function UnaryExpression(
  loc: Loc,
  operator: UnaryExpressionOperator,
  argument: Expression
): UnaryExpression {
  return {kind: ExpressionKind.Unary, loc, operator, argument};
}

export const enum UnaryExpressionOperator {
  Negative = '-',
  Not = '!',
}

export interface BlockExpression extends Node {
  readonly kind: ExpressionKind.Block;
  readonly statements: ReadonlyArray1<Statement>;
}

export function BlockExpression(
  loc: Loc,
  statements: ReadonlyArray1<Statement>
): BlockExpression {
  return {kind: ExpressionKind.Block, loc, statements};
}

export interface WrappedExpression extends Node {
  readonly kind: ExpressionKind.Wrapped;
  readonly expression: Expression;
  readonly type: Type | undefined;
}

export function WrappedExpression(
  loc: Loc,
  expression: Expression,
  type: Type | undefined = undefined
): WrappedExpression {
  return {kind: ExpressionKind.Wrapped, loc, expression, type};
}

export type Pattern =
  | BindingPattern
  | HolePattern
  | UnitPattern
  | TuplePattern
  | RecordPattern
  | ListPattern
  | QualifiedPattern
  | DeconstructPattern
  | AliasPattern
  | WrappedPattern;

export const enum PatternKind {
  Binding = 'Binding',
  Hole = 'Hole',
  Unit = 'Unit',
  Tuple = 'Tuple',
  Record = 'Record',
  List = 'List',
  Qualified = 'Qualified',
  Deconstruct = 'Deconstruct',
  Alias = 'Alias',
  Wrapped = 'Wrapped',
}

export interface BindingPattern extends Node {
  readonly kind: PatternKind.Binding;
  readonly identifier: BindingIdentifier;
  readonly modifiers:
    | {readonly access: Access; readonly mutable: boolean}
    | undefined;
}

export function BindingPattern(
  loc: Loc,
  identifier: BindingIdentifier,
  modifiers?: {readonly access: Access; readonly mutable: boolean}
): BindingPattern {
  return {kind: PatternKind.Binding, loc, identifier, modifiers};
}

export interface HolePattern extends Node {
  readonly kind: PatternKind.Hole;
}

export function HolePattern(loc: Loc): HolePattern {
  return {kind: PatternKind.Hole, loc};
}

export interface UnitPattern extends Node {
  readonly kind: PatternKind.Unit;
}

export function UnitPattern(loc: Loc): UnitPattern {
  return {kind: PatternKind.Unit, loc};
}

export interface TuplePattern extends Node {
  readonly kind: PatternKind.Tuple;
  readonly elements: ReadonlyArray2<TuplePatternElement>;
}

export function TuplePattern(
  loc: Loc,
  elements: ReadonlyArray2<TuplePatternElement>
): TuplePattern {
  return {kind: PatternKind.Tuple, loc, elements};
}

export type TuplePatternElement = {
  readonly pattern: Pattern;
  readonly type: Type | undefined;
};

export function TuplePatternElement(
  pattern: Pattern,
  type: Type | undefined
): TuplePatternElement {
  return {pattern, type};
}

export interface RecordPattern extends Node {
  readonly kind: PatternKind.Record;
  readonly properties: ReadonlyArray<RecordPatternProperty>;
}

export function RecordPattern(
  loc: Loc,
  properties: ReadonlyArray<RecordPatternProperty>
): RecordPattern {
  return {kind: PatternKind.Record, loc, properties};
}

export type RecordPatternProperty = {
  readonly key: Name;
  readonly value: Pattern;
  readonly type: Type | undefined;
  readonly optional: boolean;
};

export function RecordPatternProperty(
  key: Name,
  value: Pattern,
  type: Type | undefined,
  {optional = false}: {optional?: boolean} = {}
): RecordPatternProperty {
  return {key, value, type, optional};
}

export interface ListPattern extends Node {
  readonly kind: PatternKind.List;
  readonly items: ReadonlyArray<Pattern>;
}

export function ListPattern(
  loc: Loc,
  items: ReadonlyArray<Pattern>
): ListPattern {
  return {kind: PatternKind.List, loc, items};
}

export interface QualifiedPattern extends Node {
  readonly kind: PatternKind.Qualified;
  readonly identifiers: ReadonlyArray2<Name>;
}

export function QualifiedPattern(
  loc: Loc,
  identifiers: ReadonlyArray2<Name>
): QualifiedPattern {
  return {kind: PatternKind.Qualified, loc, identifiers};
}

export interface DeconstructPattern extends Node {
  readonly kind: PatternKind.Deconstruct;
  readonly callee: ReadonlyArray1<Name>;
  readonly arguments: ReadonlyArray<Pattern>;
}

export function DeconstructPattern(
  loc: Loc,
  callee: ReadonlyArray1<Name>,
  args: ReadonlyArray<Pattern>
): DeconstructPattern {
  return {kind: PatternKind.Deconstruct, loc, callee, arguments: args};
}

export interface AliasPattern extends Node {
  readonly kind: PatternKind.Alias;
  readonly alias: BindingName;
  readonly pattern: Pattern;
}

export function AliasPattern(
  loc: Loc,
  alias: BindingName,
  pattern: Pattern
): AliasPattern {
  return {kind: PatternKind.Alias, loc, alias, pattern};
}

export interface WrappedPattern extends Node {
  readonly kind: PatternKind.Wrapped;
  readonly pattern: Pattern;
  readonly type: Type | undefined;
}

export function WrappedPattern(
  loc: Loc,
  pattern: Pattern,
  type: Type | undefined
): WrappedPattern {
  return {kind: PatternKind.Wrapped, loc, pattern, type};
}
