import * as Immutable from 'immutable';

import {
  Term,
  abstraction,
  application,
  binding,
  conditional,
  variable,
} from './term';

/**
 * Parses a lambda calculus term.
 *
 * - `x` → `variable(x)`
 * - `(λx.y)` → `abstraction(x, y)`
 * - `(x y)` → `application(x, y)`
 * - `let x = y in z` → `binding(x, y, z)`
 * - `if x then y else z` → `conditional(x, y, z)`
 *
 * The term may have free variables which we are told are in scope by the
 * `scope` array. This array contains the names of available variables in
 * reverse order of which they were introduced.
 */
export function parse(
  source: string,
  boundVariables: ReadonlyArray<string> = [],
): Term {
  // Calculate the initial depth and initial variables map for our program.
  const depth = boundVariables.length;
  const variables = Immutable.Map<string, number>(
    boundVariables.map(
      (variable, i): [string, number] => [variable, boundVariables.length - i],
    ),
  );

  // Parse the program.
  const tokens = peekable(tokenize(source[Symbol.iterator]()));
  const term = parseTerm(tokens, depth, variables);

  // Make sure there are no remaining tokens.
  const step = tokens.next();
  if (!step.done) {
    throw new Error(`Unexpected token "${step.value.type}" expected ending`);
  }

  return term;
}

/**
 * Does the actual lambda calculus parsing on an iterator.
 */
function parseTerm(
  tokens: PeekableIterator<Token>,
  depth: number,
  variables: Immutable.Map<string, number>,
): Term {
  // Parse an abstraction.
  if (tryParseToken(tokens, TokenType.Lambda)) {
    const firstParameter = parseIdentifier(tokens);
    const parameters = [firstParameter];
    let newDepth = depth + 1;
    let newVariables = variables.set(firstParameter, newDepth);
    while (true) {
      const identifier = tryParseIdentifier(tokens);
      if (identifier === undefined) break;
      parameters.push(identifier);
      newDepth = newDepth + 1;
      newVariables = newVariables.set(identifier, newDepth);
    }
    parseToken(tokens, TokenType.Dot);
    const body = parseTerm(tokens, newDepth, newVariables);
    return parameters.reduceRight(
      (body, parameter) => abstraction(parameter, body),
      body,
    );
  }

  // Parse a binding
  if (tryParseToken(tokens, TokenType.Let)) {
    const name = parseIdentifier(tokens);
    parseToken(tokens, TokenType.Equals);
    const value = parseTerm(tokens, depth, variables);
    parseToken(tokens, TokenType.In);
    const newDepth = depth + 1;
    const newVariables = variables.set(name, newDepth);
    const body = parseTerm(tokens, newDepth, newVariables);
    return binding(name, value, body);
  }

  if (tryParseToken(tokens, TokenType.If)) {
    const test = parseTerm(tokens, depth, variables);
    parseToken(tokens, TokenType.Then);
    const consequent = parseTerm(tokens, depth, variables);
    parseToken(tokens, TokenType.Else);
    const alternate = parseTerm(tokens, depth, variables);
    return conditional(test, consequent, alternate);
  }

  // Parses an unwrapped term.
  let term = parseUnwrappedTerm(tokens, depth, variables);
  if (term === undefined) {
    const step = tokens.next();
    if (step.done) throw new Error('Unexpected ending expected term');
    throw new Error(`Unexpected token "${step.value.type}" expected term`);
  }

  // Parse as many application arguments as we can.
  while (true) {
    const argument = parseUnwrappedTerm(tokens, depth, variables);
    if (argument === undefined) {
      break;
    } else {
      term = application(term, argument);
    }
  }

  return term;
}

/**
 * Parses an unwrapped term. Either a variable or a wrapped term. Returns
 * undefined if a term could not be parsed.
 */
function parseUnwrappedTerm(
  tokens: PeekableIterator<Token>,
  depth: number,
  variables: Immutable.Map<string, number>,
): Term | undefined {
  // Parse a term inside parentheses.
  if (tryParseToken(tokens, TokenType.ParenLeft)) {
    const term = parseTerm(tokens, depth, variables);
    parseToken(tokens, TokenType.ParenRight);
    return term;
  }

  const step = tokens.peek();

  // Parse a variable.
  if (!step.done && step.value.type === TokenType.Identifier) {
    tokens.next();
    const variableDepth = variables.get(step.value.data);
    if (variableDepth === undefined) {
      throw new Error(`Could not find variable "${step.value.data}".`);
    }
    return variable(depth - variableDepth + 1);
  }

  // Parse a variable in index annotation.
  if (!step.done && step.value.type === TokenType.Index) {
    tokens.next();
    if (step.value.data > depth || step.value.data <= 0) {
      throw new Error(`Index out of bounds: 0 < ${step.value.data} < ${depth}`);
    }
    return variable(step.value.data);
  }

  // Otherwise we couldn’t parse any unwrapped terms.
  return undefined;
}

/**
 * Parses a token in the iterator and throws if it was not found.
 */
function parseToken(tokens: PeekableIterator<Token>, token: TokenType) {
  const step = tokens.next();
  if (step.done) {
    throw new Error(`Unexpected ending, expected "${token}"`);
  }
  if (step.value.type !== token) {
    throw new Error(
      `Unexpected token "${step.value.type}" expected token "${token}"`,
    );
  }
}

/**
 * Tries to parse a token of the provided type. Returns true if it was found and
 * false if it was not.
 */
function tryParseToken(
  tokens: PeekableIterator<Token>,
  token: TokenType,
): boolean {
  const step = tokens.peek();
  const found = !step.done && step.value.type === token;
  if (found) tokens.next();
  return found;
}

/**
 * Parses an identifier from the iterator. Throws if no identifier was found.
 */
function parseIdentifier(tokens: PeekableIterator<Token>): string {
  const step = tokens.next();
  if (step.done) {
    throw new Error('Unexpected ending expected identifier');
  }
  if (step.value.type !== TokenType.Identifier) {
    throw new Error(
      `Unexpected token "${step.value.type}" expected identifier`,
    );
  }
  return step.value.data;
}

/**
 * Tries to parse an identifier from the iterator. Returns nothing if an
 * identifier was not found.
 */
function tryParseIdentifier(
  tokens: PeekableIterator<Token>,
): string | undefined {
  const step = tokens.peek();
  if (step.done) return undefined;
  if (step.value.type !== TokenType.Identifier) return undefined;
  tokens.next();
  return step.value.data;
}

/**
 * The type of a token.
 */
const enum TokenType {
  Lambda = 'λ',
  Dot = '.',
  ParenLeft = '(',
  ParenRight = ')',
  Equals = '=',
  Let = 'let',
  In = 'in',
  If = 'if',
  Then = 'then',
  Else = 'else',
  Identifier = 'identifier',
  Index = 'index',
}

/**
 * A token value. Mostly the same as `TokenType` except that some types are
 * associated with a value. Like `TokenType.Identifier`.
 */
type Token =
  | {readonly type: TokenType.Lambda}
  | {readonly type: TokenType.Dot}
  | {readonly type: TokenType.ParenLeft}
  | {readonly type: TokenType.ParenRight}
  | {readonly type: TokenType.Equals}
  | {readonly type: TokenType.Let}
  | {readonly type: TokenType.In}
  | {readonly type: TokenType.If}
  | {readonly type: TokenType.Then}
  | {readonly type: TokenType.Else}
  | {readonly type: TokenType.Identifier; readonly data: string}
  | {readonly type: TokenType.Index; readonly data: number};

const identifierStart = /\w/;
const identifierContinue = /[\w\d]/;
const whitespace = /\s/;
const indexContinue = /\d/;

/**
 * Takes a source iterator of characters and returns an iterator of tokens. The
 * token iterator is much easier to work with.
 */
function* tokenize(source: Iterator<string>): IterableIterator<Token> {
  let step = source.next();
  let identifier: string | undefined = undefined;
  let index: string | undefined = undefined;
  while (true) {
    // If an identifier has been started either add to the identifier or yield
    // the completed identifier or keyword.
    if (identifier !== undefined) {
      if (!step.done && identifierContinue.test(step.value)) {
        identifier += step.value;
        step = source.next();
        continue;
      } else {
        switch (identifier) {
          case 'let':
            yield {type: TokenType.Let};
            break;
          case 'in':
            yield {type: TokenType.In};
            break;
          case 'if':
            yield {type: TokenType.If};
            break;
          case 'then':
            yield {type: TokenType.Then};
            break;
          case 'else':
            yield {type: TokenType.Else};
            break;
          default:
            yield {type: TokenType.Identifier, data: identifier};
            break;
        }
        identifier = undefined;
      }
    }
    if (index !== undefined) {
      if (!step.done && indexContinue.test(step.value)) {
        index += step.value;
        step = source.next();
        continue;
      } else {
        const actualIndex = parseInt(index, 10);
        if (isNaN(actualIndex)) {
          throw new Error(`Invalid index syntax: "%${index}"`);
        }
        yield {type: TokenType.Index, data: actualIndex};
        index = undefined;
      }
    }
    // If we are done then break out of the loop!
    if (step.done) {
      break;
    }
    if (step.value === 'λ') {
      yield {type: TokenType.Lambda};
    } else if (step.value === '.') {
      yield {type: TokenType.Dot};
    } else if (step.value === '(') {
      yield {type: TokenType.ParenLeft};
    } else if (step.value === ')') {
      yield {type: TokenType.ParenRight};
    } else if (step.value === '=') {
      yield {type: TokenType.Equals};
    } else if (step.value === '^') {
      // Start an index with this step.
      index = '';
    } else if (identifierStart.test(step.value)) {
      // Start an identifier with this step.
      identifier = step.value;
    } else if (whitespace.test(step.value)) {
      // noop
    } else {
      throw new Error(`Unexpected character "${step.value}"`);
    }
    step = source.next();
  }
}

/**
 * A peekable iterator allows you to peek the next item without consuming it.
 * Note that peekable iterators do not allow you to pass in a value with
 * `next()`. The interface of `PeekableIterator<T>` is much more limited then
 * the interface of `Iterator<T>` to allow for peeking.
 */
interface PeekableIterator<T> {
  next(): IteratorResult<T>;
  peek(): IteratorResult<T>;
}

/**
 * Turns an iterator into a peekable iterator.
 */
function peekable<T>(iterator: Iterator<T>): PeekableIterator<T> {
  let peeking: IteratorResult<T> | undefined = undefined;
  return {
    next: () => {
      if (peeking !== undefined) {
        const next = peeking;
        peeking = undefined;
        return next;
      } else {
        return iterator.next();
      }
    },
    peek: () => {
      if (peeking === undefined) {
        peeking = iterator.next();
      }
      return peeking;
    },
  };
}
