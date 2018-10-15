import {gen} from 'testcheck';

import {Diagnostics} from './diagnostics';
import {genMonomorphicType, testCheck} from './gen';
import {Prefix} from './prefix';
import {BottomType, Type} from './type';
import {unify} from './unify';

testCheck(
  'type unifies with self',
  genMonomorphicType.then(createType => {
    const prefix = Prefix.create();
    const type = createType(prefix);
    return gen.return({prefix, type});
  }),
  ({prefix, type}) => {
    const diagnostics = Diagnostics.create();
    const {error} = unify(diagnostics, prefix, type, type);
    return error === undefined;
  }
);

testCheck(
  'type unifies with structurally identical self',
  genMonomorphicType.then(createType => {
    const prefix = Prefix.create();
    const actual = createType(prefix);
    const expected = createType(prefix);
    return gen.return({prefix, actual, expected});
  }),
  ({prefix, actual, expected}) => {
    const diagnostics = Diagnostics.create();
    const {error} = unify(diagnostics, prefix, actual, expected);
    return error === undefined;
  }
);

testCheck(
  'unify solves type variables',
  genMonomorphicType.then(createType => {
    const prefix = Prefix.create();
    const type = createType(prefix);
    return gen.return({prefix, type});
  }),
  ({prefix, type: actual}) => {
    const diagnostics = Diagnostics.create();
    const identifier = prefix.add({
      kind: 'flexible',
      type: BottomType,
    });
    const expected: Type = {kind: 'Variable', identifier};
    const {error} = unify(diagnostics, prefix, actual, expected);
    const bound = prefix.find(identifier);
    if (
      error !== undefined ||
      (bound.kind === 'flexible' && bound.type.kind === 'Bottom')
    ) {
      return false;
    }
    return true;
  }
);