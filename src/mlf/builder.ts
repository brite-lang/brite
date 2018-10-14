import {Expression} from './expression';
import {Identifier} from './identifier';

export function variable(identifier: string): Expression {
  return {
    type: undefined,
    description: {
      kind: 'Variable',
      identifier: Identifier.create(identifier),
    },
  };
}

export function boolean(value: boolean): Expression {
  return {
    type: undefined,
    description: {
      kind: 'Constant',
      constant: {
        kind: 'Boolean',
        value,
      },
    },
  };
}

export function number(value: number): Expression {
  return {
    type: undefined,
    description: {
      kind: 'Constant',
      constant: {
        kind: 'Number',
        value,
      },
    },
  };
}

export function string(value: string): Expression {
  return {
    type: undefined,
    description: {
      kind: 'Constant',
      constant: {
        kind: 'String',
        value,
      },
    },
  };
}

export function function_(parameter: string, body: Expression): Expression {
  return {
    type: undefined,
    description: {
      kind: 'Function',
      parameter: Identifier.create(parameter),
      body,
    },
  };
}

export function application(
  callee: Expression,
  argument: Expression
): Expression {
  return {
    type: undefined,
    description: {
      kind: 'Application',
      callee,
      argument,
    },
  };
}

export function binding(
  binding: string,
  value: Expression,
  body: Expression
): Expression {
  return {
    type: undefined,
    description: {
      kind: 'Binding',
      binding: Identifier.create(binding),
      value,
      body,
    },
  };
}
