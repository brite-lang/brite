open TestFramework

let run () = suite "Unify" (fun () -> (
  let cases = [
    ("unify((∅), boolean, boolean)", "(∅)", []);
    ("unify((∅), number, number)", "(∅)", []);
    ("unify((a), number, number)", "(a)", []);
    ("unify((a, b), number, number)", "(a, b)", []);
    ("unify((a, b, c), number, number)", "(a, b, c)", []);
    ("unify((∅), number → number, number → number)", "(∅)", []);
    ("unify((∅), number → boolean, number → boolean)", "(∅)", []);
    ("unify((∅), number → boolean → boolean, number → boolean → boolean)", "(∅)", []);
    ("unify((∅), number → number, number → boolean)", "(∅)", ["number ≢ boolean"]);
    ("unify((∅), number → number, boolean → number)", "(∅)", ["number ≢ boolean"]);
    ("unify((∅), number → number, boolean → boolean)", "(∅)", ["number ≢ boolean"; "number ≢ boolean"]);
    ("unify((∅), number → number → number, boolean → boolean → boolean)", "(∅)", ["number ≢ boolean"; "number ≢ boolean"; "number ≢ boolean"]);
    ("unify((∅), (number → number) → number, (boolean → boolean) → boolean)", "(∅)", ["number ≢ boolean"; "number ≢ boolean"; "number ≢ boolean"]);
    ("unify((∅), number, number → number)", "(∅)", ["number ≢ number → number"]);
    ("unify((∅), number → number, number)", "(∅)", ["number → number ≢ number"]);
    ("unify((a = number), a, number)", "(a = number)", []);
    ("unify((a = number), number, a)", "(a = number)", []);
    ("unify((a = number), a, boolean)", "(a = number)", ["number ≢ boolean"]);
    ("unify((a = number), boolean, a)", "(a = number)", ["boolean ≢ number"]);
    ("unify((a ≥ number), a, number)", "(a ≥ number)", []);
    ("unify((a ≥ number), number, a)", "(a ≥ number)", []);
    ("unify((a ≥ number), a, boolean)", "(a ≥ number)", ["number ≢ boolean"]);
    ("unify((a ≥ number), boolean, a)", "(a ≥ number)", ["boolean ≢ number"]);
    ("unify((b = number, a = b), a, number)", "(b = number, a = b)", []);
    ("unify((b = number, a = b), number, a)", "(b = number, a = b)", []);
    ("unify((b = number, a = b), a, boolean)", "(b = number, a = b)", ["number ≢ boolean"]);
    ("unify((b = number, a = b), boolean, a)", "(b = number, a = b)", ["boolean ≢ number"]);
    ("unify((b = number, a ≥ b), a, number)", "(b = number, a ≥ b)", []);
    ("unify((b = number, a ≥ b), number, a)", "(b = number, a ≥ b)", []);
    ("unify((b = number, a ≥ b), a, boolean)", "(b = number, a ≥ b)", ["number ≢ boolean"]);
    ("unify((b = number, a ≥ b), boolean, a)", "(b = number, a ≥ b)", ["boolean ≢ number"]);
    ("unify((b ≥ number, a = b), a, number)", "(b ≥ number, a = b)", []);
    ("unify((b ≥ number, a = b), number, a)", "(b ≥ number, a = b)", []);
    ("unify((b ≥ number, a = b), a, boolean)", "(b ≥ number, a = b)", ["number ≢ boolean"]);
    ("unify((b ≥ number, a = b), boolean, a)", "(b ≥ number, a = b)", ["boolean ≢ number"]);
    ("unify((b ≥ number, a ≥ b), a, number)", "(b ≥ number, a ≥ b)", []);
    ("unify((b ≥ number, a ≥ b), number, a)", "(b ≥ number, a ≥ b)", []);
    ("unify((b ≥ number, a ≥ b), a, boolean)", "(b ≥ number, a ≥ b)", ["number ≢ boolean"]);
    ("unify((b ≥ number, a ≥ b), boolean, a)", "(b ≥ number, a ≥ b)", ["boolean ≢ number"]);
    ("unify((a), a, a)", "(a)", []);
    ("unify((a ≥ ⊥), a, a)", "(a)", []);
    ("unify((a = ⊥), a, a)", "(a = ⊥)", []);
    ("unify((a, b = a, c = b), b, c)", "(a, b = a, c = b)", []);
    ("unify((a, b = a, c = b), c, b)", "(a, b = a, c = b)", []);
    ("unify((a, b = a, c = b), a, b)", "(a, b = a, c = b)", []);
    ("unify((a, b = a, c = b), a, c)", "(a, b = a, c = b)", []);
    ("unify((a, b = a, c = b), b, a)", "(a, b = a, c = b)", []);
    ("unify((a, b = a, c = b), c, a)", "(a, b = a, c = b)", []);
    ("unify((a, b = a, c = b), b, a)", "(a, b = a, c = b)", []);
    ("unify((a, b = a, c = b), b, b)", "(a, b = a, c = b)", []);
    ("unify((a, b = a, c = b), c, c)", "(a, b = a, c = b)", []);
    ("unify((a, b = ∀z.a, c = ∀z.b), b, c)", "(a, b = a, c = b)", []);
    ("unify((a, b = ∀z.a, c = ∀z.b), c, b)", "(a, b = ∀z.a, c = b)", []);
    ("unify((a, b = ∀z.a, c = ∀z.b), a, b)", "(a, b = a, c = ∀z.b)", []);
    ("unify((a, b = ∀z.a, c = ∀z.b), a, c)", "(a, b = a, c = b)", []);
    ("unify((a, b = ∀z.a, c = ∀z.b), b, a)", "(a, b = a, c = ∀z.b)", []);
    ("unify((a, b = ∀z.a, c = ∀z.b), c, a)", "(a, b = a, c = b)", []);
    ("unify((a, b = ∀z.a, c = ∀z.b), b, a)", "(a, b = a, c = ∀z.b)", []);
    ("unify((a, b = ∀z.a, c = ∀z.b), b, b)", "(a, b = ∀z.a, c = ∀z.b)", []);
    ("unify((a, b = ∀z.a, c = ∀z.b), c, c)", "(a, b = ∀z.a, c = ∀z.b)", []);
    ("unify((a), a, number)", "(a = number)", []);
    ("unify((a), number, a)", "(a = number)", []);
    ("unify((a ≥ ⊥), a, number)", "(a = number)", []);
    ("unify((a ≥ ⊥), number, a)", "(a = number)", []);
    ("unify((a = ⊥), a, number)", "(a = ⊥)", ["⊥ ≢ number"]);
    ("unify((a = ⊥), number, a)", "(a = ⊥)", ["⊥ ≢ number"]);
    ("unify((b ≥ ⊥, a ≥ b), a, number)", "(b = number, a ≥ b)", []);
    ("unify((b ≥ ⊥, a ≥ b), number, a)", "(b = number, a ≥ b)", []);
    ("unify((b ≥ ⊥, a = b), a, number)", "(b = number, a = b)", []);
    ("unify((b ≥ ⊥, a = b), number, a)", "(b = number, a = b)", []);
    ("unify((b = ⊥, a ≥ b), a, number)", "(b = ⊥, a ≥ b)", ["⊥ ≢ number"]);
    ("unify((b = ⊥, a ≥ b), number, a)", "(b = ⊥, a ≥ b)", ["⊥ ≢ number"]);
    ("unify((b = ⊥, a = b), a, number)", "(b = ⊥, a = b)", ["⊥ ≢ number"]);
    ("unify((b = ⊥, a = b), number, a)", "(b = ⊥, a = b)", ["⊥ ≢ number"]);
    ("unify((b, a = b → b), a, b)", "(b, a = b → b)", ["Infinite type since `b` occurs in `b → b`."]);
    ("unify((b, a = b → b), b, a)", "(b, a = b → b)", ["Infinite type since `b` occurs in `b → b`."]);
    ("unify((b, c = b → b, a = c), a, b)", "(b, c = b → b, a = c)", ["Infinite type since `b` occurs in `b → b`."]);
    ("unify((b, c = b → b, a = c), b, a)", "(b, c = b → b, a = c)", ["Infinite type since `b` occurs in `b → b`."]);
    ("unify((b, c = b → b, a = c → c), a, b)", "(b, c = b → b, a = c → c)", ["Infinite type since `b` occurs in `c → c`."]);
    ("unify((b, c = b → b, a = c → c), b, a)", "(b, c = b → b, a = c → c)", ["Infinite type since `b` occurs in `c → c`."]);
    ("unify((a, b), a, b)", "(a, b = a)", []);
    ("unify((a, b), b, a)", "(b, a = b)", []);
    ("unify((a, b), a, b → b)", "(b, a = b → b)", []);
    ("unify((a, b), b → b, a)", "(b, a = b → b)", []);
    ("unify((a ≥ ∀x.x → x), a, number → number)", "(a = number → number)", []);
    ("unify((a ≥ ∀x.x → x), a, number → boolean)", "(a ≥ ∀x.x → x)", ["number ≢ boolean"]);
    ("unify((a = ∀x.x → x), a, number → number)", "(a = ∀x.x → x)", ["∀x.x → x ≢ number → number"]);
    ("unify((a = ∀x.x → x), a, number → boolean)", "(a = ∀x.x → x)", ["number ≢ boolean"]);
    ("unify((a ≥ ∀x.x → x, b ≥ ∀y.y → y), a, b)", "(a ≥ ∀x.x → x, b = a)", []);
    ("unify((a ≥ ∀x.x → x, b ≥ ∀y.y → y), b, a)", "(b ≥ ∀y.y → y, a = b)", []);
    ("unify((a ≥ ∀x.x → x, b ≥ ∀(y, z).y → z), a, b)", "(a ≥ ∀x.x → x, b = a)", []);
    ("unify((a ≥ ∀x.x → x, b ≥ ∀(y, z).y → z), b, a)", "(b ≥ ∀z.z → z, a = b)", []);
    ("unify((a = ∀x.x → x, b ≥ ∀y.y → y), a, b)", "(a = ∀x.x → x, b = a)", []);
    ("unify((a = ∀x.x → x, b ≥ ∀y.y → y), b, a)", "(b = ∀y.y → y, a = b)", []);
    ("unify((a ≥ ∀x.x → x, b = ∀y.y → y), a, b)", "(a = ∀x.x → x, b = a)", []);
    ("unify((a ≥ ∀x.x → x, b = ∀y.y → y), b, a)", "(b = ∀y.y → y, a = b)", []);
    ("unify((a = ∀x.x → x, b = ∀y.y → y), a, b)", "(a = ∀x.x → x, b = a)", []);
    ("unify((a = ∀x.x → x, b = ∀y.y → y), b, a)", "(b = ∀y.y → y, a = b)", []);
    ("unify((a ≥ ∀x.x → x, b ≥ ∀(y, z).y → z), a, b)", "(a ≥ ∀x.x → x, b = a)", []);
    ("unify((a ≥ ∀x.x → x, b ≥ ∀(y, z).y → z), b, a)", "(b ≥ ∀z.z → z, a = b)", []);
    ("unify((a = ∀x.x → x, b ≥ ∀(y, z).y → z), a, b)", "(a = ∀x.x → x, b = a)", []);
    ("unify((a = ∀x.x → x, b ≥ ∀(y, z).y → z), b, a)", "(b = ∀z.z → z, a = b)", []);
    ("unify((a ≥ ∀x.x → x, b = ∀(y, z).y → z), a, b)", "(a ≥ ∀x.x → x, b = ∀(y, z).y → z)", ["∀(y, z).y → z ≢ ∀x.x → x"]);
    ("unify((a ≥ ∀x.x → x, b = ∀(y, z).y → z), b, a)", "(a ≥ ∀x.x → x, b = ∀(y, z).y → z)", ["∀(y, z).y → z ≢ ∀z.z → z"]);
    ("unify((a = ∀x.x → x, b = ∀(y, z).y → z), a, b)", "(a = ∀x.x → x, b = ∀(y, z).y → z)", ["∀(y, z).y → z ≢ ∀x.x → x"]);
    ("unify((a = ∀x.x → x, b = ∀(y, z).y → z), b, a)", "(a = ∀x.x → x, b = ∀(y, z).y → z)", ["∀(y, z).y → z ≢ ∀z.z → z"]);
    ("unify((a ≥ ∀x.x → x, b = number → number), a, b)", "(a = number → number, b = number → number)", []);
    ("unify((a ≥ ∀x.x → x, b = number → number), b, a)", "(a = number → number, b = number → number)", []);
    ("unify((a, b = a → a), a, b)", "(a, b = a → a)", ["Infinite type since `a` occurs in `a → a`."]);
    ("unify((a, b = a → a), b, a)", "(a, b = a → a)", ["Infinite type since `a` occurs in `a → a`."]);
    ("unify((a, b = ∀c.c → a), a, b)", "(a, b = ∀c.c → a)", ["Infinite type since `a` occurs in `∀c.c → a`."]);
    ("unify((a, b = ∀c.c → a), b, a)", "(a, b = ∀c.c → a)", ["Infinite type since `a` occurs in `∀c.c → a`."]);
    ("unify((a = ⊥, b = ⊥), a, b)", "(a = ⊥, b = a)", []);
    ("unify((a = ⊥, b = ⊥), b, a)", "(b = ⊥, a = b)", []);
    ("unify((a = ⊥, b = ∀c.c → c), a, b)", "(a = ⊥, b = ∀c.c → c)", ["⊥ ≢ ∀c.c → c"]);
    ("unify((a = ⊥, b = ∀c.c → c), b, a)", "(a = ⊥, b = ∀c.c → c)", ["⊥ ≢ ∀c.c → c"]);
    ("unify((a, b), a, b)", "(a, b = a)", []);
    ("unify((a, b), b, a)", "(b, a = b)", []);
    ("unify((a ≥ ⊥, b ≥ ⊥), a, b)", "(a, b = a)", []);
    ("unify((a ≥ ⊥, b ≥ ⊥), b, a)", "(b, a = b)", []);
    ("unify((a = ⊥, b ≥ ⊥), a, b)", "(a = ⊥, b = a)", []);
    ("unify((a = ⊥, b ≥ ⊥), b, a)", "(b = ⊥, a = b)", []);
    ("unify((a ≥ ⊥, b = ⊥), a, b)", "(a = ⊥, b = a)", []);
    ("unify((a ≥ ⊥, b = ⊥), b, a)", "(b = ⊥, a = b)", []);
    ("unify((a = ⊥, b = ⊥), a, b)", "(a = ⊥, b = a)", []);
    ("unify((a = ⊥, b = ⊥), b, a)", "(b = ⊥, a = b)", []);
    ("unify((a ≥ ∀x.x → x, b ≥ ∀y.y → y), a, b)", "(a ≥ ∀x.x → x, b = a)", []);
    ("unify((a ≥ ∀x.x → x, b ≥ ∀y.y → y), b, a)", "(b ≥ ∀y.y → y, a = b)", []);
    ("unify((a = ∀x.x → x, b ≥ ∀y.y → y), a, b)", "(a = ∀x.x → x, b = a)", []);
    ("unify((a = ∀x.x → x, b ≥ ∀y.y → y), b, a)", "(b = ∀y.y → y, a = b)", []);
    ("unify((a ≥ ∀x.x → x, b = ∀y.y → y), a, b)", "(a = ∀x.x → x, b = a)", []);
    ("unify((a ≥ ∀x.x → x, b = ∀y.y → y), b, a)", "(b = ∀y.y → y, a = b)", []);
    ("unify((a = ∀x.x → x, b = ∀y.y → y), a, b)", "(a = ∀x.x → x, b = a)", []);
    ("unify((a = ∀x.x → x, b = ∀y.y → y), b, a)", "(b = ∀y.y → y, a = b)", []);
    ("unify((a ≥ ∀x.x → x, b ≥ ∀x.x → x), a, b)", "(a ≥ ∀x.x → x, b = a)", []);
    ("unify((a ≥ ∀x.x → x, b ≥ ∀x.x → x), b, a)", "(b ≥ ∀x.x → x, a = b)", []);
    ("unify((a = ∀x.x → x, b ≥ ∀x.x → x), a, b)", "(a = ∀x.x → x, b = a)", []);
    ("unify((a = ∀x.x → x, b ≥ ∀x.x → x), b, a)", "(b = ∀x.x → x, a = b)", []);
    ("unify((a ≥ ∀x.x → x, b = ∀x.x → x), a, b)", "(a = ∀x.x → x, b = a)", []);
    ("unify((a ≥ ∀x.x → x, b = ∀x.x → x), b, a)", "(b = ∀x.x → x, a = b)", []);
    ("unify((a = ∀x.x → x, b = ∀x.x → x), a, b)", "(a = ∀x.x → x, b = a)", []);
    ("unify((a = ∀x.x → x, b = ∀x.x → x), b, a)", "(b = ∀x.x → x, a = b)", []);
    ("unify((x), x, x)", "(x)", []);
    ("unify((a ≥ number), a, number)", "(a ≥ number)", []);
    ("unify((a = number), a, number)", "(a = number)", []);
    ("unify((a ≥ number), a, boolean)", "(a ≥ number)", ["number ≢ boolean"]);
    ("unify((a = number), a, boolean)", "(a = number)", ["number ≢ boolean"]);
    ("unify((a ≥ number), number, a)", "(a ≥ number)", []);
    ("unify((a = number), number, a)", "(a = number)", []);
    ("unify((a ≥ number), boolean, a)", "(a ≥ number)", ["boolean ≢ number"]);
    ("unify((a = number), boolean, a)", "(a = number)", ["boolean ≢ number"]);
    ("unify((a, b = a), a, b)", "(a, b = a)", []);
    ("unify((a, b = a), b, a)", "(a, b = a)", []);
    ("unify((a, b ≥ a), a, b)", "(a, b ≥ a)", []);
    ("unify((a, b ≥ a), b, a)", "(a, b ≥ a)", []);
    ("unify((a ≥ ∀x.x → number, b ≥ ∀y.y → boolean), a, b)", "(a ≥ ∀x.x → number, b ≥ ∀y.y → boolean)", ["number ≢ boolean"]);
    ("unify((a ≥ ∀x.x → number, b ≥ ∀y.y → boolean), b, a)", "(a ≥ ∀x.x → number, b ≥ ∀y.y → boolean)", ["boolean ≢ number"]);
    ("unify((a = ∀x.x → number, b ≥ ∀y.y → boolean), a, b)", "(a = ∀x.x → number, b ≥ ∀y.y → boolean)", ["number ≢ boolean"]);
    ("unify((a = ∀x.x → number, b ≥ ∀y.y → boolean), b, a)", "(a = ∀x.x → number, b ≥ ∀y.y → boolean)", ["boolean ≢ number"]);
    ("unify((a ≥ ∀x.x → number, b = ∀y.y → boolean), a, b)", "(a ≥ ∀x.x → number, b = ∀y.y → boolean)", ["number ≢ boolean"]);
    ("unify((a ≥ ∀x.x → number, b = ∀y.y → boolean), b, a)", "(a ≥ ∀x.x → number, b = ∀y.y → boolean)", ["boolean ≢ number"]);
    ("unify((a = ∀x.x → number, b = ∀y.y → boolean), a, b)", "(a = ∀x.x → number, b = ∀y.y → boolean)", ["number ≢ boolean"]);
    ("unify((a = ∀x.x → number, b = ∀y.y → boolean), b, a)", "(a = ∀x.x → number, b = ∀y.y → boolean)", ["boolean ≢ number"]);
    ("unify((a ≥ ∀x.x → number, b ≥ ∀y.y → number), a, b)", "(a ≥ ∀x.x → number, b = a)", []);
    ("unify((a ≥ ∀x.x → number, b ≥ ∀y.y → number), b, a)", "(b ≥ ∀y.y → number, a = b)", []);
    ("unify((a = ∀x.x → number, b ≥ ∀y.y → number), a, b)", "(a = ∀x.x → number, b = a)", []);
    ("unify((a = ∀x.x → number, b ≥ ∀y.y → number), b, a)", "(b = ∀y.y → number, a = b)", []);
    ("unify((a ≥ ∀x.x → number, b = ∀y.y → number), a, b)", "(a = ∀x.x → number, b = a)", []);
    ("unify((a ≥ ∀x.x → number, b = ∀y.y → number), b, a)", "(b = ∀y.y → number, a = b)", []);
    ("unify((a = ∀x.x → number, b = ∀y.y → number), a, b)", "(a = ∀x.x → number, b = a)", []);
    ("unify((a = ∀x.x → number, b = ∀y.y → number), b, a)", "(b = ∀y.y → number, a = b)", []);
    ("unify((c, a ≥ ∀x.x → c, b ≥ ∀y.y → a), a, b)", "(c, a ≥ ∀x.x → c, b ≥ ∀y.y → a)", ["Infinite type since `c` occurs in `∀x.x → c`."]);
    ("unify((c, a ≥ ∀x.x → c, b ≥ ∀y.y → a), b, a)", "(c, a ≥ ∀x.x → c, b ≥ ∀y.y → a)", ["Infinite type since `c` occurs in `∀x.x → c`."]);
    ("unify((c, a = ∀x.x → c, b ≥ ∀y.y → a), a, b)", "(c, a = ∀x.x → c, b ≥ ∀y.y → a)", ["Infinite type since `c` occurs in `∀x.x → c`."]);
    ("unify((c, a = ∀x.x → c, b ≥ ∀y.y → a), b, a)", "(c, a = ∀x.x → c, b ≥ ∀y.y → a)", ["Infinite type since `c` occurs in `∀x.x → c`."]);
    ("unify((c, a ≥ ∀x.x → c, b = ∀y.y → a), a, b)", "(c, a ≥ ∀x.x → c, b = ∀y.y → a)", ["Infinite type since `c` occurs in `∀x.x → c`."]);
    ("unify((c, a ≥ ∀x.x → c, b = ∀y.y → a), b, a)", "(c, a ≥ ∀x.x → c, b = ∀y.y → a)", ["Infinite type since `c` occurs in `∀x.x → c`."]);
    ("unify((c, a = ∀x.x → c, b = ∀y.y → a), a, b)", "(c, a = ∀x.x → c, b = ∀y.y → a)", ["Infinite type since `c` occurs in `∀x.x → c`."]);
    ("unify((c, a = ∀x.x → c, b = ∀y.y → a), b, a)", "(c, a = ∀x.x → c, b = ∀y.y → a)", ["Infinite type since `c` occurs in `∀x.x → c`."]);
    ("unify((a ≥ ∀x.x → number, b ≥ ∀y.y → y), a, b)", "(a ≥ number → number, b = a)", []);
    ("unify((a ≥ ∀x.x → number, b ≥ ∀y.y → y), b, a)", "(b ≥ number → number, a = b)", []);
    ("unify((a = ∀x.x → number, b ≥ ∀y.y → y), a, b)", "(a = ∀x.x → number, b ≥ ∀y.y → y)", ["∀x.x → number ≢ number → number"]);
    ("unify((a = ∀x.x → number, b ≥ ∀y.y → y), b, a)", "(a = ∀x.x → number, b ≥ ∀y.y → y)", ["∀x.x → number ≢ number → number"]);
    ("unify((a ≥ ∀x.x → number, b = ∀y.y → y), a, b)", "(a ≥ ∀x.x → number, b = ∀y.y → y)", ["∀y.y → y ≢ number → number"]);
    ("unify((a ≥ ∀x.x → number, b = ∀y.y → y), b, a)", "(a ≥ ∀x.x → number, b = ∀y.y → y)", ["∀y.y → y ≢ number → number"]);
    ("unify((a = ∀x.x → number, b = ∀y.y → y), a, b)", "(a = ∀x.x → number, b = ∀y.y → y)", ["∀x.x → number ≢ number → number"; "∀y.y → y ≢ number → number"]);
    ("unify((a = ∀x.x → number, b = ∀y.y → y), b, a)", "(a = ∀x.x → number, b = ∀y.y → y)", ["∀y.y → y ≢ number → number"; "∀x.x → number ≢ number → number"]);
    ("unify((a ≥ ∀x.x → number, b), a, b → boolean)", "(a ≥ ∀x.x → number, b)", ["number ≢ boolean"]);
    ("unify((a ≥ ∀x.x → number, b), a, b → number)", "(b, a = b → number)", []);
    ("unify((a = ∀x.x → number, b), a, b → boolean)", "(a = ∀x.x → number, b)", ["number ≢ boolean"]);
    ("unify((a = ∀x.x → number, b), a, b → number)", "(a = ∀x.x → number, b)", ["∀x.x → number ≢ b → number"]);
    ("unify((a ≥ ∀x.x → number), a, boolean → boolean)", "(a ≥ ∀x.x → number)", ["number ≢ boolean"]);
    ("unify((a ≥ ∀x.x → number), a, boolean → number)", "(a = boolean → number)", []);
    ("unify((a = ∀x.x → number), a, boolean → boolean)", "(a = ∀x.x → number)", ["number ≢ boolean"]);
    ("unify((a = ∀x.x → number), a, boolean → number)", "(a = ∀x.x → number)", ["∀x.x → number ≢ boolean → number"]);
    ("unify((a ≥ ∀x.x → number), a, a → boolean)", "(a ≥ ∀x.x → number)", ["number ≢ boolean"]);
    ("unify((a ≥ ∀x.x → number), a, a → number)", "(a ≥ ∀x.x → number)", ["Infinite type since `a` occurs in `a → number`."]);
    ("unify((a = ∀x.x → number), a, a → boolean)", "(a = ∀x.x → number)", ["number ≢ boolean"]);
    ("unify((a = ∀x.x → number), a, a → number)", "(a = ∀x.x → number)", ["Infinite type since `a` occurs in `a → number`."]);
    ("unify((a ≥ ∀x.x → number, b), b → boolean, a)", "(a ≥ ∀x.x → number, b)", ["boolean ≢ number"]);
    ("unify((a ≥ ∀x.x → number, b), b → number, a)", "(b, a = b → number)", []);
    ("unify((a = ∀x.x → number, b), b → boolean, a)", "(a = ∀x.x → number, b)", ["boolean ≢ number"]);
    ("unify((a = ∀x.x → number, b), b → number, a)", "(a = ∀x.x → number, b)", ["∀x.x → number ≢ b → number"]);
    ("unify((a ≥ ∀x.x → number), boolean → boolean, a)", "(a ≥ ∀x.x → number)", ["boolean ≢ number"]);
    ("unify((a ≥ ∀x.x → number), boolean → number, a)", "(a = boolean → number)", []);
    ("unify((a = ∀x.x → number), boolean → boolean, a)", "(a = ∀x.x → number)", ["boolean ≢ number"]);
    ("unify((a = ∀x.x → number), boolean → number, a)", "(a = ∀x.x → number)", ["∀x.x → number ≢ boolean → number"]);
    ("unify((a ≥ ∀x.x → number), a → boolean, a)", "(a ≥ ∀x.x → number)", ["boolean ≢ number"]);
    ("unify((a ≥ ∀x.x → number), a → number, a)", "(a ≥ ∀x.x → number)", ["Infinite type since `a` occurs in `a → number`."]);
    ("unify((a = ∀x.x → number), a → boolean, a)", "(a = ∀x.x → number)", ["boolean ≢ number"]);
    ("unify((a = ∀x.x → number), a → number, a)", "(a = ∀x.x → number)", ["Infinite type since `a` occurs in `a → number`."]);
    ("unify((a, b = ∀x.x → x), a, b)", "(a = ∀x.x → x, b = a)", []);
    ("unify((a, b = ∀x.x → x), b, a)", "(b = ∀x.x → x, a = b)", []);
    ("unify((a, b ≥ ∀x.x → x), a, b)", "(a ≥ ∀x.x → x, b = a)", []);
    ("unify((a, b ≥ ∀x.x → x), b, a)", "(b ≥ ∀x.x → x, a = b)", []);
    ("unify((a ≥ ∀x.x → number, b ≥ ∀y.y → boolean), a, b)", "(a ≥ ∀x.x → number, b ≥ ∀y.y → boolean)", ["number ≢ boolean"]);
    ("unify((a ≥ ∀x.x → number, b ≥ ∀y.y → boolean), b, a)", "(a ≥ ∀x.x → number, b ≥ ∀y.y → boolean)", ["boolean ≢ number"]);
    ("unify((a ≥ ∀x.x → number, b ≥ ∀y.y → number), a, b)", "(a ≥ ∀x.x → number, b = a)", []);
    ("unify((a ≥ ∀x.x → number, b ≥ ∀y.y → number), b, a)", "(b ≥ ∀y.y → number, a = b)", []);
    ("unify((a = ∀x.x → number, b ≥ ∀y.y → boolean), a, b)", "(a = ∀x.x → number, b ≥ ∀y.y → boolean)", ["number ≢ boolean"]);
    ("unify((a = ∀x.x → number, b ≥ ∀y.y → boolean), b, a)", "(a = ∀x.x → number, b ≥ ∀y.y → boolean)", ["boolean ≢ number"]);
    ("unify((a = ∀x.x → number, b ≥ ∀y.y → number), a, b)", "(a = ∀x.x → number, b = a)", []);
    ("unify((a = ∀x.x → number, b ≥ ∀y.y → number), b, a)", "(b = ∀y.y → number, a = b)", []);
    ("unify((a ≥ ∀x.x → number, b = ∀y.y → boolean), a, b)", "(a ≥ ∀x.x → number, b = ∀y.y → boolean)", ["number ≢ boolean"]);
    ("unify((a ≥ ∀x.x → number, b = ∀y.y → boolean), b, a)", "(a ≥ ∀x.x → number, b = ∀y.y → boolean)", ["boolean ≢ number"]);
    ("unify((a ≥ ∀x.x → number, b = ∀y.y → number), a, b)", "(a = ∀x.x → number, b = a)", []);
    ("unify((a ≥ ∀x.x → number, b = ∀y.y → number), b, a)", "(b = ∀y.y → number, a = b)", []);
    ("unify((a = ∀x.x → number, b = ∀y.y → boolean), a, b)", "(a = ∀x.x → number, b = ∀y.y → boolean)", ["number ≢ boolean"]);
    ("unify((a = ∀x.x → number, b = ∀y.y → boolean), b, a)", "(a = ∀x.x → number, b = ∀y.y → boolean)", ["boolean ≢ number"]);
    ("unify((a = ∀x.x → number, b = ∀y.y → number), a, b)", "(a = ∀x.x → number, b = a)", []);
    ("unify((a = ∀x.x → number, b = ∀y.y → number), b, a)", "(b = ∀y.y → number, a = b)", []);
    ("unify((a = ∀x.x → x, b = ∀x.x → x), a, b)", "(a = ∀x.x → x, b = a)", []);
    ("unify((a = ∀x.x → x, b = ∀x.x → x), b, a)", "(b = ∀x.x → x, a = b)", []);
    ("unify((a, b = a, c = b, d = c, e = d, f = e → e), a, f)", "(a, b = a, c = b, d = c, e = d, f = e → e)", ["Infinite type since `a` occurs in `e → e`."]);
    ("unify((a, b = a, c = b, d = c, e = d, f = e → e), f, a)", "(a, b = a, c = b, d = c, e = d, f = e → e)", ["Infinite type since `a` occurs in `e → e`."]);
    ("unify((a = ∀x.x → x, b = ∀y.y → y), a → a, a → b)", "(a = ∀x.x → x, b = a)", []);
    ("unify((a = ∀x.x → x, b = ∀y.y → y), a → b, a → a)", "(b = ∀y.y → y, a = b)", []);
    ("unify((t = ∀(a = ∀x.x → x).a → a, u = ∀(b = ∀y.y → y, c = ∀z.z → z).b → c), t, u)", "(t = ∀(a = ∀x.x → x).a → a, u = t)", []);
    ("unify((t = ∀(a = ∀x.x → x).a → a, u = ∀(b = ∀y.y → y, c = ∀z.z → z).b → c), u, t)", "(u = ∀(c = ∀z.z → z).c → c, t = u)", []);
    ("unify((a = ∀(x, x = ∀z.z → x).x → x, b), a, b)", "(a = ∀(x, x = ∀z.z → x).x → x, b = a)", []);
    ("unify((a = ∀(x, x = ∀z.z → x).x → x, b), b, a)", "(b = ∀(x, x = ∀z.z → x).x → x, a = b)", []);
    ("unify((a = ∀(x, x = ∀z.z → x).x → x, b, c, d, e), a, (b → c) → d → e)", "(a = ∀(x, x = ∀z.z → x).x → x, c, e = c, d, b)", ["∀z.z → x ≢ b → c"; "∀z.z → x ≢ d → e"]);
    ("unify((a = ∀(x, x = ∀z.z → x).x → x, b, c, d, e), (b → c) → d → e, a)", "(a = ∀(x, x = ∀z.z → x).x → x, e, d, b, c = e)", ["∀z.z → x ≢ b → c"; "∀z.z → x ≢ d → e"]);
    ("unify((a ≥ ∀(x, x ≥ ∀z.z → x).x → x, b, c, d, e), a, (b → c) → d → e)", "(b, c, d = b, e = c, a = (b → c) → d → e)", []);
    ("unify((a ≥ ∀(x, x ≥ ∀z.z → x).x → x, b, c, d, e), (b → c) → d → e, a)", "(d, b = d, e, c = e, a = (b → c) → d → e)", []);
    ("unify((a = ∀(x, x = ∀z.z → x).x → x, b = ∀(x, x = ∀z.z → x).x → x), a, b)", "(a = ∀(x, x2 = ∀z.z → x).x2 → x2, b = a)", []);
    ("unify((a = ∀(x, x2, x = ∀z.z → x2 → x).x → x, b = ∀(x, x2, x = ∀z.z → x2 → x).x → x), a, b)", "(a = ∀(x, x2, x3 = ∀z.z → x2 → x).x3 → x3, b = a)", []);
    ("unify((a = ∀(x1, x1 = ∀z.z → x1).x1 → x1, b = ∀(x1, x1 = ∀z.z → x1).x1 → x1), a, b)", "(a = ∀(x1, x2 = ∀z.z → x1).x2 → x2, b = a)", []);
    ("unify((a = ∀(x1, x2, x1 = ∀z.z → x2 → x1).x1 → x1, b = ∀(x1, x2, x1 = ∀z.z → x2 → x1).x1 → x1), a, b)", "(a = ∀(x1, x2, x3 = ∀z.z → x2 → x1).x3 → x3, b = a)", []);
    ("unify((a = ∀(x5, x5 = ∀z.z → x5).x5 → x5, b = ∀(x5, x5 = ∀z.z → x5).x5 → x5), a, b)", "(a = ∀(x5, x6 = ∀z.z → x5).x6 → x6, b = a)", []);
    ("unify((a = ∀(x, x = ∀z.z → x).x → x, b = ∀(x, x = ∀z.z → x).x → x), b, a)", "(b = ∀(x, x2 = ∀z.z → x).x2 → x2, a = b)", []);
    ("unify((a = ∀(x, x2, x = ∀z.z → x2 → x).x → x, b = ∀(x, x2, x = ∀z.z → x2 → x).x → x), b, a)", "(b = ∀(x, x2, x3 = ∀z.z → x2 → x).x3 → x3, a = b)", []);
    ("unify((a = ∀(x1, x1 = ∀z.z → x1).x1 → x1, b = ∀(x1, x1 = ∀z.z → x1).x1 → x1), b, a)", "(b = ∀(x1, x2 = ∀z.z → x1).x2 → x2, a = b)", []);
    ("unify((a = ∀(x1, x2, x1 = ∀z.z → x2 → x1).x1 → x1, b = ∀(x1, x2, x1 = ∀z.z → x2 → x1).x1 → x1), b, a)", "(b = ∀(x1, x2, x3 = ∀z.z → x2 → x1).x3 → x3, a = b)", []);
    ("unify((a = ∀(x5, x5 = ∀z.z → x5).x5 → x5, b = ∀(x5, x5 = ∀z.z → x5).x5 → x5), b, a)", "(b = ∀(x5, x6 = ∀z.z → x5).x6 → x6, a = b)", []);
    ("unify((a ≥ ∀x.x → x), a, number → number)", "(a = number → number)", []);
    ("unify((a ≥ ∀x.x → x, b), a, number → b)", "(b = number, a = number → b)", []);
    ("unify((a = ∀(x = number).x), a, number)", "(a = number)", []);
    ("unify((a ≥ ∀(x ≥ ∀y.y → y).x), a, number → number)", "(a = number → number)", []);
    ("unify((a = ∀(x ≥ ∀y.y → y).x), a, number → number)", "(a = ∀y.y → y)", ["∀y.y → y ≢ number → number"]);
    ("unify((a ≥ ∀(x = ∀y.y → y).x), a, number → number)", "(a = number → number)", []);
    ("unify((a = ∀(x = ∀y.y → y).x), a, number → number)", "(a = ∀y.y → y)", ["∀y.y → y ≢ number → number"]);
    ("unify((a ≥ ∀y.y → y), a, number → number)", "(a = number → number)", []);
    ("unify((a ≥ ∀(b = ∀x.x → x).b), a, number → number)", "(a = number → number)", []);
    ("unify((a ≥ ∀(b = ∀(c = ∀x.x → x).c).b), a, number → number)", "(a = number → number)", []);
    ("unify((a ≥ ∀(b = ∀(c = ∀(d = ∀x.x → x).d).c).b), a, number → number)", "(a = number → number)", []);
    ("unify((a ≥ ∀(b = ∀x.x → x).b → b), a, (number → number) → number → number)", "(a ≥ ∀(b = ∀x.x → x).b → b)", ["∀x.x → x ≢ number → number"; "∀x.x → x ≢ number → number"]);
    ("unify((a ≥ ∀(b = ∀(c = ∀x.x → x).c).b → b), a, (number → number) → number → number)", "(a ≥ ∀(b = ∀x.x → x).b → b)", ["∀x.x → x ≢ number → number"; "∀x.x → x ≢ number → number"]);
    ("unify((a ≥ ∀(b = ∀(c = ∀(d = ∀x.x → x).d).c).b → b), a, (number → number) → number → number)", "(a ≥ ∀(b = ∀x.x → x).b → b)", ["∀x.x → x ≢ number → number"; "∀x.x → x ≢ number → number"]);
    ("unify((a ≥ ∀(b = ∀x.x → x).b → b), a, (number → number) → number → number)", "(a ≥ ∀(b = ∀x.x → x).b → b)", ["∀x.x → x ≢ number → number"; "∀x.x → x ≢ number → number"]);
    ("unify((a ≥ ∀(b = ∀(c = ∀x.x → x).c → c).b), a, (number → number) → number → number)", "(a ≥ ∀(c = ∀x.x → x).c → c)", ["∀x.x → x ≢ number → number"; "∀x.x → x ≢ number → number"]);
    ("unify((a ≥ ∀(b = ∀(c = ∀(d = ∀x.x → x).d → d).c).b), a, (number → number) → number → number)", "(a ≥ ∀(d = ∀x.x → x).d → d)", ["∀x.x → x ≢ number → number"; "∀x.x → x ≢ number → number"]);
    ("unify((a ≥ ∀x.x), a, number)", "(a = number)", []);
    ("unify((a ≥ ∀x.x), number, a)", "(a = number)", []);
    ("unify((a ≥ ∀x.x, b ≥ ∀x.x), a, b)", "(a, b = a)", []);
    ("unify((a ≥ ∀x.x, b ≥ ∀x.x), b, a)", "(b, a = b)", []);
    ("unify((a = ∀(x, y).number → number), a, number → number)", "(a = number → number)", []);
    ("unify((a = ∀(x, y).y → number, b = ∀(x, y).y → number), a, b)", "(a = ∀y.y → number, b = a)", []);
    ("unify((a = ∀(x, y).y → number, b = ∀y.y → number), a, b)", "(a = ∀y.y → number, b = a)", []);
    ("unify((a = ∀(x, y).y → number, b = ∀y.y → number), b, a)", "(b = ∀y.y → number, a = b)", []);
    ("unify((a = ∀(y, x).y → number, b = ∀(y, x).y → number), a, b)", "(a = ∀y.y → number, b = a)", []);
    ("unify((a = ∀(y, x).y → number, b = ∀y.y → number), a, b)", "(a = ∀y.y → number, b = a)", []);
    ("unify((a = ∀(y, x).y → number, b = ∀y.y → number), b, a)", "(b = ∀y.y → number, a = b)", []);
    ("unify((x = ∀(a ≥ ∀b.b → b).a → a, y = ∀c.(c → c) → (c → c)), x, y)", "(y = ∀c.(c → c) → c → c, x = ∀(a ≥ ∀b.b → b).a → a)", ["∀(a ≥ ∀b.b → b).a → a ≢ ∀c.(c → c) → c → c"]);
    ("unify((x ≥ ∀(a ≥ ∀b.b → b).a → a, y = ∀c.(c → c) → (c → c)), x, y)", "(x = ∀c.(c → c) → c → c, y = x)", []);
    ("unify((x = ∀(a ≥ ∀b.b → b).a → a, y ≥ ∀c.(c → c) → (c → c)), x, y)", "(y ≥ ∀c.(c → c) → c → c, x = ∀(a ≥ ∀b.b → b).a → a)", ["∀(a ≥ ∀b.b → b).a → a ≢ ∀c.(c → c) → c → c"]);
    ("unify((x ≥ ∀(a ≥ ∀b.b → b).a → a, y ≥ ∀c.(c → c) → (c → c)), x, y)", "(x ≥ ∀c.(c → c) → c → c, y = x)", []);
    ("unify((x = ∀(a ≥ ∀b.b → b).a → a, y = ∀c.(c → c) → (c → c)), y, x)", "(y = ∀c.(c → c) → c → c, x = ∀(a ≥ ∀b.b → b).a → a)", ["∀(a ≥ ∀b.b → b).a → a ≢ ∀c.(c → c) → c → c"]);
    ("unify((x ≥ ∀(a ≥ ∀b.b → b).a → a, y = ∀c.(c → c) → (c → c)), y, x)", "(y = ∀c.(c → c) → c → c, x = y)", []);
    ("unify((x = ∀(a ≥ ∀b.b → b).a → a, y ≥ ∀c.(c → c) → (c → c)), y, x)", "(y ≥ ∀c.(c → c) → c → c, x = ∀(a ≥ ∀b.b → b).a → a)", ["∀(a ≥ ∀b.b → b).a → a ≢ ∀c.(c → c) → c → c"]);
    ("unify((x ≥ ∀(a ≥ ∀b.b → b).a → a, y ≥ ∀c.(c → c) → (c → c)), y, x)", "(y ≥ ∀c.(c → c) → c → c, x = y)", []);
  ] in

  let prefix = Prefix.create () in

  cases |> List.iter (fun (input, output, expected_errors) -> (
    let name = match List.length expected_errors with
    | 0 -> Printf.sprintf "%s = %s" input output
    | 1 -> Printf.sprintf "%s = %s with 1 error" input output
    | n -> Printf.sprintf "%s = %s with %n errors" input output n
    in
    test name (fun () -> (
      let (result, actual_errors) = Diagnostics.collect (fun () -> Prefix.level prefix (fun () -> (
        let tokens = Parser.tokenize (Stream.of_string input) in
        assert (Stream.next tokens = Identifier "unify");
        assert (Stream.next tokens = Glyph ParenthesesLeft);
        let bounds = Parser.parse_prefix tokens in
        List.iter (fun (name, bound) -> assert (Prefix.add prefix name bound = None)) bounds;
        assert (Stream.next tokens = Glyph Comma);
        let type1 = Parser.parse_monotype tokens in
        assert (Stream.next tokens = Glyph Comma);
        let type2 = Parser.parse_monotype tokens in
        assert (Stream.next tokens = Glyph ParenthesesRight);
        Stream.empty tokens;
        let result = Unify.unify prefix type1 type2 in
        assert_equal (Printer.print_prefix prefix) output;
        result
      ))) in
      assert (match result with Ok () -> actual_errors = [] | Error _ -> actual_errors <> []);
      List.iter2 assert_equal (List.map Printer.print_diagnostic actual_errors) expected_errors
    ))
  ))
))
