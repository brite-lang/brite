let rec print_monotype t =
  match t.Type.monotype_description with
  | Variable { name } -> name
  | Boolean -> "boolean"
  | Number -> "number"

  | Function { parameter = { monotype_description = Function _ } as parameter; body } ->
    Printf.sprintf "(%s) → %s" (print_monotype parameter) (print_monotype body)

  | Function { parameter; body } ->
    Printf.sprintf "%s → %s" (print_monotype parameter) (print_monotype body)

  | RowEmpty -> "(||)"

  | RowExtension { entries; extension = None } ->
    let entries = Nel.map print_row_entry entries in
    let entries = String.concat ", " (Nel.to_list entries) in
    Printf.sprintf "(| %s |)" entries

  | RowExtension { entries; extension = Some extension } ->
    let entries = Nel.map print_row_entry entries in
    let entries = String.concat ", " (Nel.to_list entries) in
    let extension = print_monotype extension in
    Printf.sprintf "(| %s | %s |)" entries extension

  (* This is not great... *)
  | Error _ -> "%error"

and print_row_entry (label, type_) =
  Printf.sprintf "%s: %s" label (print_monotype type_)

let rec print_polytype t =
  match t.Type.polytype_description with
  | Monotype t -> print_monotype t
  | Bottom _ -> "⊥"

  | Quantify { body; bounds =
      ((name, { bound_flexibility = Flexible; bound_type = { polytype_description = Bottom _; _ } }), []) } ->
    let body = print_monotype body in
    Printf.sprintf "∀%s.%s" name body

  | Quantify { bounds; body } ->
    let body = print_monotype body in
    let bounds = Nel.map print_bound bounds in
    Printf.sprintf "∀(%s).%s" (String.concat ", " (Nel.to_list bounds)) body

and print_bound (name, bound) =
  match bound with
  | { Type.bound_flexibility = Flexible; bound_type = { polytype_description = Bottom _; _ } } -> name
  | { bound_flexibility; bound_type } ->
    let bound_flexibility = match bound_flexibility with Flexible -> "≥" | Rigid -> "=" in
    let bound_type = print_polytype bound_type in
    Printf.sprintf "%s %s %s" name bound_flexibility bound_type

let print_prefix prefix =
  match List.map print_bound prefix with
  | [] -> "(∅)"
  | bounds -> Printf.sprintf "(%s)" (String.concat ", " bounds)

let print_diagnostic diagnostic =
  match diagnostic with
  | Diagnostics.Error error -> (
    match error with
    | UnboundVariable { name } ->
      Printf.sprintf "Unbound variable `%s`." name

    | UnboundTypeVariable { name } ->
      Printf.sprintf "Unbound variable `%s`." name

    | IncompatibleTypes { type1; type2 } ->
      Printf.sprintf "%s ≢ %s" type1 type2

    | InfiniteType { name; type_ } ->
      Printf.sprintf "Infinite type since `%s` occurs in `%s`." name type_

    | IncompatibleKinds { kind1; kind2 } ->
      Printf.sprintf "Incompatible kinds %s and %s." kind1 kind2

    | InfiniteKind -> "Infinite kind."
  )
