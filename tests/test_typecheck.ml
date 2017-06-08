open OUnit2
module TA = Type_annotations
module T  = Typing.Types

exception ParseError

let parse tokens =
  match Parse.Parser.onix Parse.Lexer.read tokens with
  | Some s -> Simple.Of_onix.expr s
  | None -> raise ParseError

let typ s =
  let maybe_t =
    CCOpt.flat_map
      (fun t -> Typing.(Annotations.to_type Types.Environment.default t))
      (Parse.Parser.typ Parse.Lexer.read (Lexing.from_string s))
  in
  CCOpt.get_exn maybe_t

let infer tenv env tokens =
  parse tokens
  |> Typing.(Typecheck.Infer.expr tenv env)

let check tenv env tokens expected_type =
  Typing.(Typecheck.Check.expr tenv env (parse tokens) expected_type)

let test_infer_expr input expected_type _ =
  let expected_type = typ expected_type in
  let typ =
    let open Typing in
    infer Types.Environment.default
      Typing_env.initial
      (Lexing.from_string input)
  in
  assert_equal
    ~cmp:T.T.equiv
    ~printer:T.T.Print.string_of_type
    expected_type
    typ

let test_check input expected_type _=
  let expected_type = typ expected_type in
  let tast =
    let open Typing in
    check
      Types.Environment.default
      Typing_env.initial
      (Lexing.from_string input)
      expected_type
  in ignore tast

let test_var _ =
  let tenv = Typing.(Typing_env.(add "x" Types.Builtins.int initial)) in
  let typ =
    infer Typing.Types.Environment.default tenv (Lexing.from_string "x")
  in
  assert_equal Typing.Types.Builtins.int typ

let test_fail typefun _ =
  try
    ignore @@ typefun ();
    assert_failure "type error not detected"
  with Typing.Typecheck.TypeError _ -> ()

let test_infer_expr_fail input =
  test_fail @@ fun () ->
  let open Typing in
  infer
    Types.Environment.default
    Typing_env.initial
    (Lexing.from_string input)

let test_check_fail input expected_type =
  let expected_type = typ expected_type in
  test_fail @@ fun () ->
  let open Typing in
  check
    Types.Environment.default
    Typing_env.initial
    (Lexing.from_string input)
    expected_type

let one_singleton = T.Builtins.interval @@ T.Intervals.singleton_of_int 1

let testsuite =
  "typecheck">:::

  ("infer_var">::test_var) ::
  (* ----- Positive tests ----- *)
  List.map (fun (name, expr, result) -> name >:: test_infer_expr expr result)
    [
      "infer_const_int", "1", "1";
      "infer_const_bool", "true", "true";
      "infer_builtins_not", "__not", "((true -> false) & (false -> true))";
      "infer_lambda", "x /*: Int */: 1", "Int -> 1";
      "infer_lambda_var", "x /*: Int */: x", "Int -> Int";
      "infer_apply", "(x /*: Int */: x) 1", "Int";
      ("infer_arrow_annot",
       "x /*: Int -> Int */: x",
       "(Int -> Int) -> Int -> Int");
      "infer_let_1", "let x = 1; in x", "1";
      "infer_let_2", "let x /*:Int*/ = 1; in x", "Int";
      "infer_let_3", "let x /*:Int*/ = 1; y = x; in y", "Int";
      "infer_let_4", "let x = 1; y = x; in y", "?";
      "infer_let_5", "let x = x; in x", "?";
      "infer_let_6", "let x /*: Int -> Int */ = y: y; in x", "Int -> Int";
      ("infer_let_7", "let x /*: Int -> Int -> Int */ = y: y: y; in x",
       "Int -> Int -> Int");
      "infer_shadowing", "let x = true; in let x = 1; in x", "1";
      "infer_union", "x /*: Int | Bool */: x", "(Int | Bool) -> (Int | Bool)";
      "infer_intersection", "x /*: Int & Int */: x", "Int -> Int";
      "test_not_true", "__not true", "false";
      "test_list", "[1 true false]", "Cons (1, Cons(true, Cons(false, nil)))";
      "infer_type_where_1", "x /*: X where X = Int */: x", "Int -> Int";
      "infer_type_where_2", "x /*: Int where X = Int */: x", "Int -> Int";
      ("infer_ite_classic", "let x /*: Bool */ = true; in if x then 1 else 2",
       "1 | 2");
      "infer_ite_dead_branch", "if true then 1 else __add 1 true", "1";
      ("infer_ite_typecase_1",
       "let x /*: Int | Bool */ = 1; in if isInt x then x else __not x",
       "Int | Bool");
      "infer_plus", "1 + 1", "Int";
      "infer_string", "\"aze\"", "\"aze\"";
      "infer_string_annot", "x /*: \"foo\" */: x", "\"foo\" -> \"foo\"";
    ] @
  (* ----- Negative tests ----- *)
  List.map (fun (name, expr) -> name >:: test_infer_expr_fail expr)
    [
      "infer_fail_unbound_var", "x";
      "infer_fail_apply", "1 1";
      "infer_fail_apply2", "(x /*: Bool */: x) 1";
      "infer_fail_apply3", "(x /*: Int */: x) true";
      "infer_fail_notalist", "Cons (1, 2)";
      "infer_fail_where", "(x /*: X where X = Bool */: x) 1";
      ("infer_fail_ite_not_bool_cond",
       "let x /*: Int | Bool */ = 1; in if x then 1 else 1");
      ("infer_fail_ite_no_refine_1",
       "let x /*: Bool */ = true; in if x then __add x 1 else x");
      ("infer_fail_ite_no_refine_2",
       "let f /*: Int -> Bool */ = x: true; x = 1; \
        in if f x then __add x 1 else __not x");
      "infer_fail_plus_not_int", "1 + true";
    ] @
  (* ------ positive check ----- *)
  List.map (fun (name, expr, result) -> name >:: test_check expr result)
    [
      "check_const_one", "1", "1";
      "check_const_int", "1", "Int";
      "check_const_union", "1", "1 | Bool";
      "check_arrow_1", "x: x", "Int -> Int";
      "check_arrow_2", "x: x", "1 -> Int";
      "check_intersect_arrow", "x: x", "(Int -> Int) & (Bool -> Bool)";
      "check_let", "let x = 1; in y: y", "Int -> Int";
      "check_ite", "let x /*: Bool */ = true; in if x then 1 else 2", "Int";
      ("check_ite_refine",
       "let x /*: Int | Bool */ = 1; in if isInt x then __add x 1 else true",
       "Int | true");
      ("check_ite_dead_branch",
       "let x = true; in if x then true else false",
       "true");
      "check_cons", "[1]", "Cons(1, nil)";
      "check_cons_union", "[1]", "Cons(1, nil) | Cons(Bool, nil)";
      "check_add", "1 + 1", "Int";
      "check_minus", "1 - 1", "Int";
      "check_unary_minus", "- (-1)", "1";
    ] @
  List.map (fun (name, expr, result) -> name >:: test_check_fail expr result)
    [
      (* ------ negative check ----- *)
      "check_fail_const_int", "1", "Bool";
      "check_fail_unbound_var", "x", "1";
      "check_fail_bad_intersect_arrow", "x: x", "(Int -> Bool) & (Bool -> Int)";
      "check_fail_inside_let", "let x = y: y; in x", "Int -> Int";
      "check_fail_ite_not_bool", "if 1 then 1 else 1", "Int";
      "check_fail_cons", "[1]", "Cons(Bool, nil)";
      "check_fail_cons_length", "[1]", "Cons(1, Cons(1, nil))";
      "check_fail_unary_minus", "-1", "1";
    ]
