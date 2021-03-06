type identifier

type variable_declaration_kind =
  | Var
  | Let
  | Const

type statement
type expression
type arrow_function_body
type pattern
type program

val identifier: string -> identifier
val expression_statement: expression -> statement
val return_statement: expression -> statement
val if_statement: expression -> statement list -> statement list -> statement
val variable_declaration: variable_declaration_kind -> pattern -> expression option -> statement
val identifier_expression: identifier -> expression
val boolean_literal: bool -> expression
val numeric_literal: float -> expression
val arrow_function_expression: pattern list -> arrow_function_body -> expression
val expression_arrow_function_body: expression -> arrow_function_body
val block_statement_arrow_function_body: statement list -> arrow_function_body
val assignment_expression: pattern -> expression -> expression
val conditional_expression: expression -> expression -> expression -> expression
val call_expression: expression -> expression list -> expression
val identifier_pattern: identifier -> pattern
val program: statement list -> program
val print_program: program -> string
