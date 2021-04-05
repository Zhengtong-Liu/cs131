open List;;

let rec subset a b = match a with 
  [] -> true
  | head :: tail -> (List.mem head b) && (subset tail b);;


let equal_sets a b = (subset a b) && (subset b a);;


let rec set_union a b = match a with
  [] -> b     
  | head :: tail -> if (not (List.mem head b))
  then (set_union tail (head :: b))
  else (set_union tail b);;


let rec set_all_union a = match a with
  [] -> []
  | head :: tail -> head @ (set_all_union tail);;

(* cannot write such member that implments 'self_member s' in Ocaml, as Ocaml
wii do type inference, and if we test if s is a member of s in Ocaml (like mem s s), 
the compiler will complain that as s is of type 'a, the second s should be 'a list 
rather than 'a *)

let rec computed_fixed_point eq f x = 
    if (eq x (f x)) then x else (computed_fixed_point eq f (f x));;


type ('nonterminal, 'terminal) symbol =
      | N of 'nonterminal
      | T of 'terminal;;


let rec extract l = match l with
  [] -> [] 
  | head :: tail -> (match head with 
  N a -> (a :: (extract tail))
  | T _ -> (extract tail));;

let rec get_reachable_symbols params = 
        let rules = (fst params) in
        let reachable_symbols = (snd params) in
        if (List.length rules) = 0 then (rules, reachable_symbols)
        else (let tmp_rule = (List.hd rules) in
        let res_rules = (List.tl rules) in
        let tmp_symbol = (fst tmp_rule) in
        let rhs = (snd tmp_rule) in
        (if (List.mem tmp_symbol reachable_symbols) then
        (let nonterminal = (extract rhs) in
        (get_reachable_symbols (res_rules, (set_union reachable_symbols nonterminal)))) else
        (get_reachable_symbols (res_rules, reachable_symbols))));;

let equal_second_element a b = equal_sets (snd a) (snd b);;


let rec computed_fixed_point_2 eq f (rules, symbols) = 
    if (eq (rules, symbols) (f (rules, symbols))) then (rules, symbols) else
    (computed_fixed_point_2 eq f (rules, (snd (f (rules, symbols)))));;

let filter_reachable grammar = 
      let start_symbol = (fst grammar) in
      let rules = (snd grammar) in
      let reachable_symbols = (snd (computed_fixed_point_2 equal_second_element 
      get_reachable_symbols (rules, [start_symbol]))) in
      let filtered_rules = List.filter (fun a -> (List.mem (fst a) 
      reachable_symbols)) rules in
      (start_symbol, filtered_rules);;