# Generics

## Generic Parameters

GenericParameters : `<` GenericParameterList `>`

GenericParameterList :
  - GenericParameter `,`?
  - GenericParameter `,` GenericParameterList

GenericParameter :
  - Identifier
  - Identifier `:` GenericParameterBoundList

GenericParameterBoundList :
  - GenericParameterBound
  - GenericParameterBound `+` GenericParameterBoundList

GenericParameterBound : ReferenceType

## Generic Arguments

GenericArguments : `<` GenericArgumentList `>`

GenericArgumentList :
  - GenericArgument `,`?
  - GenericArgument `,` GenericArgumentList

GenericArgument : Type