type subset_nonterminals =
  | Stmts | Stmt | Nstmt | Expr | Id | Num | Binop ;;

let my_grammar = 
  (Stmts,
    function 
    | Stmts -> 
      [[N Stmt; N Stmts];
      [N Stmt]]
    | Stmt -> 
      [[N Nstmt];
      [T"if"; T"("; N Expr; T")"; N Stmt]]
    | Nstmt ->
      [[T";"]; [N Expr; T";"]; [T"return"; T";"];
      [T"return"; N Expr; T";"]; [T"break"; T";"];
      [T"continue"; T";"]; [T"while";T"("; N Expr; T")"; N Stmt];
      [T"{"; N Stmts; T"}"];
      [T"if"; T"("; N Expr; T")"; N Nstmt; T"else"; N Stmt]]
    | Expr -> 
      [[N Id; N Binop; N Num];
      [N Id; N Binop; N Id];
      [N Num; N Binop; N Id];
      [N Num; N Binop; N Num]]
    | Id -> 
      [[T"i"]; [T"j"]; [T"k"]; [T"l"]; [T"m"]; [T"n"]]
    | Num ->
      [[T"0"]; [T"1"]; [T"2"]; [T"3"]; [T"4"];
	    [T"5"]; [T"6"]; [T"7"]; [T"8"]; [T"9"]]
    | Binop ->
      [[T"=="]; [T">"]; [T"<"]; [T"!="]; [T"<="]; [T">="]]
      )

let accept_empty_suffix = function
  | _::_ -> None
  | x -> Some x

let fragment_1 = ["while"; "("; "i"; ">"; "1"; ")"; "return"; ";"]

let make_matcher_test = 
  ((make_matcher my_grammar accept_empty_suffix fragment_1) 
  = Some [])

let fragment_2 = ["if"; "("; "k"; "=="; "1"; ")"; "return"; ";"]
let make_parser_test =
  match make_parser my_grammar fragment_2 with
  | Some tree -> parse_tree_leaves tree = fragment_2
  | _ -> false