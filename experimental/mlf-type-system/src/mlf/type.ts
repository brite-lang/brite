import {BindingMap} from './bindings';

/**
 * A type in our type system. Actually an alias for `Polytype`.
 */
export type Type = Polytype;

/**
 * Monotypes are types which do not contain quantifiers.
 */
export type Monotype = {
  readonly description: MonotypeDescription;
};

/**
 * Polytypes are types which do contain quantifiers. All monotypes are also
 * polytypes. In general when we say “type” we are referring to a polytype.
 */
export type Polytype = {
  readonly description: PolytypeDescription;
};

export type MonotypeDescription =
  | {readonly kind: 'Boolean'}
  | {readonly kind: 'Number'}
  | {readonly kind: 'String'}
  | {
      readonly kind: 'Function';
      readonly parameter: Monotype;
      readonly body: Monotype;
    }
  | {
      readonly kind: 'Variable';
      readonly name: string;
    };

export type PolytypeDescription =
  | MonotypeDescription
  | {
      readonly kind: 'Quantify';
      readonly name: string;
      readonly bound: Bound;
      readonly body: Polytype;
    };

/**
 * Bound of a polytype quantification. An undefined type bound should be treated
 * as the bottom type.
 */
export type Bound = {
  readonly kind: 'flexible' | 'rigid';
  readonly type: Type | undefined;
};

export namespace Type {
  /**
   * Returns true if the provided type is monomorphic.
   */
  export function isMonotype(type: Type): type is Monotype {
    return type.description.kind !== 'Quantify';
  }

  /**
   * Prints a type to a display string using the standard syntax for types in
   * academic literature. Particularly the [MLF][1] paper we implement.
   *
   * Brite programmers will not be familiar with this syntax. It is for
   * debugging purposes only.
   *
   * [1]: http://pauillac.inria.fr/~remy/work/mlf/icfp.pdf
   */
  export function toDisplayString(type: Type): string {
    switch (type.description.kind) {
      case 'Variable':
        return type.description.name;

      case 'Boolean':
        return 'boolean';
      case 'Number':
        return 'number';
      case 'String':
        return 'string';

      case 'Function': {
        let param = toDisplayString(type.description.parameter);
        const body = toDisplayString(type.description.body);
        if (type.description.parameter.description.kind === 'Function') {
          param = `(${param})`;
        }
        return `${param} → ${body}`;
      }

      case 'Quantify': {
        if (
          type.description.body.description.kind !== 'Quantify' &&
          type.description.bound.kind === 'flexible' &&
          type.description.bound.type === undefined
        ) {
          const name = type.description.name;
          const body = Type.toDisplayString(type.description.body);
          return `∀${name}.${body}`;
        }
        const bounds = [];
        while (type.description.kind === 'Quantify') {
          if (
            type.description.bound.kind === 'flexible' &&
            type.description.bound.type === undefined
          ) {
            bounds.push(type.description.name);
          } else {
            const name = type.description.name;
            const kind = type.description.bound.kind === 'flexible' ? '≥' : '=';
            const bound =
              type.description.bound.type !== undefined
                ? Type.toDisplayString(type.description.bound.type)
                : '⊥';
            bounds.push(`${name} ${kind} ${bound}`);
          }
          type = type.description.body;
        }
        const body = Type.toDisplayString(type);
        return `∀(${bounds.join(', ')}).${body}`;
      }

      default:
        const never: never = type.description;
        return never;
    }
  }

  /**
   * Iterates through every free variable in the polytype. Will iterate over the
   * same free variable twice if it appears multiple times.
   */
  export function forEachFreeVariable(
    type: Polytype,
    f: (name: string) => void
  ): void {
    return forEachFreeVariable(new BindingMap(), type, f);

    function forEachFreeVariable(
      scope: BindingMap<string, undefined>,
      type: Polytype,
      f: (name: string) => void
    ) {
      switch (type.description.kind) {
        case 'Variable': {
          const name = type.description.name;
          if (!scope.has(name)) f(name);
          return;
        }

        case 'Quantify': {
          let pops = 0;
          while (type.description.kind === 'Quantify') {
            pops++;
            scope.push(type.description.name, undefined);
            if (type.description.bound.type !== undefined) {
              forEachFreeVariable(scope, type.description.bound.type, f);
            }
            type = type.description.body;
          }
          forEachFreeVariable(scope, type, f);
          for (let i = 0; i < pops; i++) scope.pop();
          return;
        }

        case 'Function': {
          forEachFreeVariable(scope, type.description.parameter, f);
          forEachFreeVariable(scope, type.description.body, f);
          return;
        }

        case 'Boolean':
        case 'Number':
        case 'String':
          return;

        default:
          const never: never = type.description;
          f(never);
          return;
      }
    }
  }

  /**
   * Iterates through every free variable in the polytype giving the caller the
   * opportunity to return a new type to replace that free variable. If the same
   * type variable appears twice then a transform will be attempted twice.
   */
  export function transformFreeVariables(
    type: Polytype,
    f: (name: string) => Monotype | undefined
  ): Polytype {
    return transformPolytypeFreeVariables(new BindingMap(), type, f) || type;

    function transformPolytypeFreeVariables(
      scope: BindingMap<string, undefined>,
      type: Polytype,
      f: (name: string) => Monotype | undefined
    ): Polytype | undefined {
      switch (type.description.kind) {
        case 'Quantify': {
          let changed = false;
          const quantifications = [];
          while (type.description.kind === 'Quantify') {
            const {name, bound} = type.description;
            scope.push(name, undefined);
            if (bound.type !== undefined) {
              const t1 = bound.type;
              const t2 = transformPolytypeFreeVariables(scope, t1, f);
              if (t2 === undefined) {
                quantifications.push({name, bound});
              } else {
                changed = true;
                const newBound = {kind: bound.kind, type: t2};
                quantifications.push({name, bound: newBound});
              }
            } else {
              quantifications.push({name, bound});
            }
            type = type.description.body;
          }
          let newType = transformPolytypeFreeVariables(scope, type, f);
          if (changed === true || newType !== undefined) {
            newType = newType || type;
            for (let i = quantifications.length - 1; i >= 0; i--) {
              scope.pop();
              const {name, bound} = quantifications[i]!; // tslint:disable-line no-non-null-assertion
              newType = Type.quantify(name, bound, newType);
            }
            return newType;
          } else {
            for (let i = 0; i < quantifications.length; i++) scope.pop();
            return undefined;
          }
        }

        default:
          return transformMonotypeFreeVariables(scope, type as Monotype, f);
      }
    }

    function transformMonotypeFreeVariables(
      scope: BindingMap<string, undefined>,
      type: Monotype,
      f: (name: string) => Monotype | undefined
    ): Monotype | undefined {
      switch (type.description.kind) {
        case 'Variable': {
          const name = type.description.name;
          if (!scope.has(name)) {
            return f(name);
          } else {
            return undefined;
          }
        }

        case 'Function': {
          const a1 = type.description.parameter;
          const b1 = type.description.body;
          const a2 = transformMonotypeFreeVariables(scope, a1, f);
          const b2 = transformMonotypeFreeVariables(scope, b1, f);
          return a2 !== undefined || b2 !== undefined
            ? Type.function_(a2 || a1, b2 || b1)
            : undefined;
        }

        case 'Boolean':
        case 'Number':
        case 'String':
          return undefined;

        default:
          const never: never = type.description;
          return f(never);
      }
    }
  }

  export function variable(name: string): Monotype {
    return {
      description: {kind: 'Variable', name},
    };
  }

  export const boolean: Monotype = {
    description: {kind: 'Boolean'},
  };

  export const number: Monotype = {
    description: {kind: 'Number'},
  };

  export const string: Monotype = {
    description: {kind: 'String'},
  };

  export function function_(parameter: Monotype, body: Monotype): Monotype {
    return {
      description: {kind: 'Function', parameter, body},
    };
  }

  export function quantify(
    name: string,
    bound: Bound,
    body: Polytype
  ): Polytype {
    return {
      description: {kind: 'Quantify', name, bound, body},
    };
  }

  export function quantifyUnbounded(name: string, body: Polytype): Polytype {
    return {
      description: {kind: 'Quantify', name, bound: unbounded, body},
    };
  }

  export function rigidBound(type: Polytype): Bound {
    return {kind: 'rigid', type};
  }

  export function flexibleBound(type: Polytype): Bound {
    return {kind: 'flexible', type};
  }

  export const unbounded: Bound = {kind: 'flexible', type: undefined};
}
