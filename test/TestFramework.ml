let depth = ref 0
let failures = ref 0

let success_mark = "\027[32m✔\027[39m"
let failure_mark = "\027[31m✘\027[39m"

let indentation () = String.make (!depth * 2) ' '

exception Assert_equal_failure of string * string

let assert_equal a b =
  if a <> b then raise (Assert_equal_failure (a, b))

let test name f =
  let result = try (
    f ();
    Ok ()
  ) with
  | Failure reason -> Error (Printf.sprintf "Failure(%S)" reason)
  | Assert_equal_failure (a, b) -> Error (Printf.sprintf "%s ≠ %s" a b)
  in
  let (mark, failure_reason) = match result with
  | Ok () -> (success_mark, "")
  | Error reason ->
    failures := !failures + 1;
    (failure_mark, Printf.sprintf " \027[31m── error:\027[39m %s" reason)
  in
  Printf.printf "%s%s \027[90m%s\027[39m%s\n"
    (indentation ())
    mark
    name
    failure_reason

let suite name f =
  if !depth = 0 then Printf.printf "\n";
  Printf.printf "%s%s\n" (indentation ()) name;
  depth := !depth + 1;
  f ();
  depth := !depth - 1

let exit_tests () =
  Printf.printf
    "\nTests finished with %i failure%s.\n\n"
    !failures
    (if !failures = 1 then "" else "s");
  exit !failures
