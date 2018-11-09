type monotype = {
  monotype_free_variables: StringSet.t Lazy.t;
  monotype_description: monotype_description;
}

and monotype_description =
  (* `x` *)
  | Variable of { name: string }

  (* `boolean` *)
  | Boolean

  (* `number` *)
  | Number

  (* `T1 → T2` *)
  | Function of { parameter: monotype; body: monotype }

type bound_kind = Flexible | Rigid

type bound = {
  bound_kind: bound_kind;
  bound_type: polytype;
}

and polytype = {
  polytype_normal: bool;
  polytype_free_variables: StringSet.t Lazy.t;
  polytype_description: polytype_description;
}

and polytype_description =
  (* Inherits from monotype. *)
  | Monotype of monotype

  (* `⊥` *)
  | Bottom

  (* `∀x.T`, `∀(x = T1).T2`, `∀(x ≥ T1).T2` *)
  | Quantify of { bounds: (string * bound) list; body: monotype }

(* Our type constructors always create types in normal form according to
 * Definition 1.5.5 of the [MLF thesis][1]. Practically this means only
 * quantified types need to be transformed into their normal form variants.
 *
 * These constructors are not suitable for representing parsed types. As we will
 * perform structural transformations on the types which changes the AST. For
 * example, monotype bounds are inlined. However, the user may be interested in
 * sharing a monotype in a bound since the type is long to write out by hand.
 *
 * [1]: https://pastel.archives-ouvertes.fr/file/index/docid/47191/filename/tel-00007132.pdf *)

(* Creates a new variable monotype. *)
let variable name =
  {
    monotype_free_variables = lazy (StringSet.singleton name);
    monotype_description = Variable { name };
  }

(* Boolean monotype. *)
let boolean =
  {
    monotype_free_variables = lazy StringSet.empty;
    monotype_description = Boolean;
  }

(* Number monotype. *)
let number =
  {
    monotype_free_variables = lazy StringSet.empty;
    monotype_description = Number;
  }

(* Creates a new function monotype. *)
let function_ parameter body =
  {
    monotype_free_variables = lazy (StringSet.union
      (Lazy.force parameter.monotype_free_variables) (Lazy.force body.monotype_free_variables));
    monotype_description = Function { parameter; body }
  }

(* Converts a monotype into a polytype. *)
let to_polytype t =
  {
    polytype_normal = true;
    polytype_free_variables = t.monotype_free_variables;
    polytype_description = Monotype t;
  }

(* Bottom polytype. *)
let bottom =
  {
    polytype_normal = true;
    polytype_free_variables = lazy StringSet.empty;
    polytype_description = Bottom;
  }

(* Creates a type bound. *)
let bound kind type_ = { bound_kind = kind; bound_type = type_ }

(* A flexible bottom bound. *)
let unbounded = bound Flexible bottom

(* Quantifies a monotype by some bounds. The free type variables of quantified
 * types will not include the free type variables of unused bounds. This is to
 * be consistent with the normal form of the quantified type. *)
let quantify bounds body =
  if bounds = [] then to_polytype body else
  {
    polytype_normal = false;
    polytype_free_variables = lazy (List.fold_right (fun (name, bound) free -> (
      if not (StringSet.mem name free) then free else
      free |> StringSet.remove name |> StringSet.union (Lazy.force bound.bound_type.polytype_free_variables)
    )) bounds (Lazy.force body.monotype_free_variables));
    polytype_description = Quantify { bounds; body };
  }

(* Determines if a type needs some substitutions by looking at the types free
 * variables. If a substitution exists for any free variable then the type does
 * need a substitution. *)
let needs_substitution substitutions free_variables =
  (* NOTE: If the size of substitutions is smaller then the size of free
   * variables it would be faster to iterate through substitutions. However,
   * looking up the size of maps/sets in OCaml is O(n). *)
  if StringMap.is_empty substitutions then false else
  StringSet.exists (fun name -> StringMap.mem name substitutions) free_variables

(* Substitutes the free variables of the provided type with a substitution if
 * one was made available in the substitutions map. Returns nothing if no
 * substitution was made. *)
let rec substitute_monotype substitutions t =
  match t.monotype_description with
  (* If a substitution exists for this variable then replace our variable with
   * that substitution. *)
  | Variable { name } -> StringMap.find_opt name substitutions
  (* Types with no type variables will never be substituted. *)
  | Boolean
  | Number
    -> None
  (* Look at the free variables for our type. If we don’t need a substitution
   * then just return the type. We put this here before
   * unconditionally recursing. *)
  | _ when not (needs_substitution substitutions (Lazy.force t.monotype_free_variables)) -> None
  (* Composite types are unconditionally substituted since according to the
   * check above their free type variables overlap with the type variables which
   * need to be substituted. *)
  | Function { parameter; body } ->
    let parameter = match substitute_monotype substitutions parameter with Some t -> t | None -> parameter in
    let body = match substitute_monotype substitutions body with Some t -> t | None -> body in
    Some (function_ parameter body)

(* Substitutes the free variables of the provided type with a substitution if
 * one was made available in the substitutions map. Does not substitute
 * variables bound locally if they shadow a substitution. Returns nothing if no
 * substitution was made. *)
let rec substitute_polytype substitutions t =
  match t.polytype_description with
  (* Monotypes are substituted with a different function. *)
  | Monotype t -> (match substitute_monotype substitutions t with Some t -> Some (to_polytype t) | None -> None)
  (* No free type variables in the bottom type! *)
  | Bottom -> None
  (* Look at the free variables for our type. If we don’t need a substitution
   * then just return the type. We put this here before
   * unconditionally recursing. *)
  | _ when not (needs_substitution substitutions (Lazy.force t.polytype_free_variables)) -> None
  (* Substitute the quantified bounds and the quantified body. *)
  | Quantify { bounds; body } ->
    let (substitutions, bounds) = List.fold_left (fun (substitutions, bounds) entry -> (
      let (name, bound) = entry in
      let bound_type = substitute_polytype substitutions bound.bound_type in
      let substitutions = StringMap.remove name substitutions in
      match bound_type with
      | None -> (substitutions, entry :: bounds)
      | Some bound_type -> (substitutions, (name, { bound with bound_type }) :: bounds)
    )) (substitutions, []) bounds in
    let body = match substitute_monotype substitutions body with Some t -> t | None -> body in
    (* Create the final quantified type. It is in normal form if the type we
     * originally substituted was in normal form. Substitution only expands
     * variables to other monotypes so a substitution will never affect whether
     * or not we are in normal form. *)
    let t' = quantify (List.rev bounds) body in
    let t' = { t' with polytype_normal = t.polytype_normal } in
    Some t'

(* Converts a type to normal form as described in Definition 1.5.5 of the [MLF
 * thesis][1]. Returns nothing if the type is already in normal form.
 *
 * [1]: https://pastel.archives-ouvertes.fr/file/index/docid/47191/filename/tel-00007132.pdf *)
let rec normal t =
  if t.polytype_normal then None else
  match t.polytype_description with
  (* These polytypes should always have `polytype_normal = true`. *)
  | Bottom -> assert false
  | Monotype _ -> assert false

  | Quantify { bounds; body } ->
    (* Loops through the bounds of a quantified type in reverse order and
     * removes unused bounds and if the body is a variable then we inline the
     * bound referenced by that variable. Tail recursive and processes the
     * reversed bounds list created by the `loop` function defined below.
     *
     * The arguments are defined as:
     *
     * - `free`: The free type variables at this point in the iteration. We drop
     *   bounds which are not contained in this set.
     * - `bounds`: The forward list of bounds we are accumulating.
     * - `bounds_rev`: The reverse list of bounds we are iterating.
     * - `body`: The current body of the quantified type we are normalizing. *)
    let rec loop_rev free bounds bounds_rev body =
      match bounds_rev, body.monotype_description with
      (* If we have no more bounds to iterate then construct our
       * final polytype. *)
      | [], _ ->
        if bounds = [] then (
          to_polytype body
        ) else (
          {
            polytype_normal = true;
            polytype_free_variables = lazy free;
            polytype_description = Quantify { bounds; body }
          }
        )

      (* If our body is a variable and our last bound is referenced by the
       * variable then replace our body with that bound. *)
      | (name, bound) :: bounds_rev, Variable { name = name' }
          when name = name' && bounds = [] -> (
        let body = bound.bound_type in
        let free = Lazy.force body.polytype_free_variables in
        match body.polytype_description with
        | Bottom -> body
        | Monotype body -> loop_rev free [] bounds_rev body
        | Quantify { bounds; body } -> loop_rev free bounds bounds_rev body
      )

      (* If our bound is unused then don’t add it to our final bounds list.
       * Otherwise add the bound and its free variables. *)
      | (name, bound) :: bounds_rev, _ ->
        if StringSet.mem name free then (
          let free = free
            |> StringSet.remove name
            |> StringSet.union (Lazy.force bound.bound_type.polytype_free_variables)
          in
          loop_rev free ((name, bound) :: bounds) bounds_rev body
        ) else (
          loop_rev free bounds bounds_rev body
        )
    in
    (* Loops through the bounds of a quantified type inlining monotype bounds.
     * Tail recursive and accumulates a reversed list of bounds which we pass
     * to the `loop_rev` function defined above.
     *
     * The arguments are defined as:
     *
     * - `seen`: A set containing the names of bounds we have seen while
     *   iterating which have not been renamed.
     * - `captured`: A set containing the names of bounds which have been
     *   captured by the substitutions map. All the names in this set must
     *   continue to be available at the point in which we apply the
     *   substitution. Therefore if we see a bound which shadows a name in
     *   `captured` we must rename that bound.
     * - `substitutions`: A map of variable names to monotypes which should be
     *   substituted for those variable names.
     * - `bounds`: The tail of the current bounds we are iterating through.
     *   Every iteration removes the head from the bounds list and processes it.
     * - `bounds_rev`: An accumulator. We add all of the bounds that we remove
     *   from `bounds` to this list in reverse. *)
    let rec loop seen captured substitutions bounds bounds_rev =
      match bounds with
      (* If we have processed all our bounds then return the new quantified
       * type in normal form. *)
      | [] ->
        let body = match substitute_monotype substitutions body with Some body -> body | None -> body in
        let free = Lazy.force body.monotype_free_variables in
        loop_rev free [] bounds_rev body

      (* Process a the next bound in the list. *)
      | entry :: bounds -> (
        (* Convert the bound’s type to normal form. *)
        let entry = match normal (snd entry).bound_type with
        | Some t -> let (name, bound) = entry in (name, { bound with bound_type = t })
        | None -> entry
        in
        match (snd entry).bound_type.polytype_description with
        (* If our bound is a monotype then we want to inline that monotype
         * wherever a reference appears. Ignoring the bound kind. We also want
         * to rename any free variables that this bound captures in
         * subsequent bounds. *)
        | Monotype t ->
          let (name, _) = entry in
          let t = match substitute_monotype substitutions t with Some t -> t | None -> t in
          let substitutions = StringMap.add name t substitutions in
          let captured = StringSet.union captured (Lazy.force t.monotype_free_variables) in
          loop seen captured substitutions bounds bounds_rev

        (* Process a bound to be added to the resulting list. *)
        | _ ->
          (* If the name of this bound is captured in the substitutions map then
           * we need to generate a new name. Then we need to substitute that new
           * name for the old one.
           *
           * If the name of this bound is not captured then we need to make sure
           * we don’t substitute this name anymore and that we add the name to
           * `seen` so we don’t override it when generating a new name. *)
          let (seen, captured, substitutions, entry) = if StringSet.mem (fst entry) captured then (
            let (name, bound) = entry in
            let name' = Namer.unique (fun name -> StringSet.mem name seen || StringSet.mem name captured) name in
            let entry = (name', bound) in
            let substitutions = StringMap.add name (variable name') substitutions in
            let captured = StringSet.add name' captured in
            (seen, captured, substitutions, entry)
          ) else (
            let (name, _) = entry in
            let substitutions = StringMap.remove name substitutions in
            let seen = StringSet.add name seen in
            (seen, captured, substitutions, entry)
          ) in
          (* Substitute the bound type. *)
          let entry = match substitute_polytype substitutions (snd entry).bound_type with
          | Some t -> let (name, bound) = entry in (name, { bound with bound_type = t })
          | None -> entry
          in
          (* Add the entry to our reverse bounds list and return. *)
          let bounds_rev = entry :: bounds_rev in
          loop seen captured substitutions bounds bounds_rev
      )
    in
    let t = loop StringSet.empty StringSet.empty StringMap.empty bounds [] in
    Some t