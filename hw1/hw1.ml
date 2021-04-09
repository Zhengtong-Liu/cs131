open Stdlib;;
open List;;

(* Q1: subset, whether a is a subset of b *)
let rec subset a b = match a with 
  [] -> true
  | head :: tail -> (List.mem head b) && (subset tail b);;

(* Q2: equal sets, whether two sets are equal *)
let equal_sets a b = (subset a b) && (subset b a);;

(* Q3: set union, union all sets *)
let rec set_union a b = match a with
  [] -> b     
  | head :: tail -> if (not (List.mem head b))
  then (set_union tail (head :: b))
  else (set_union tail b);;

(* Q4: set all union, union all sets as a member of a list *)
let rec set_all_union a = match a with
  [] -> []
  | head :: tail -> head @ (set_all_union tail);;

(* Q5: 'self_member s' cannot be implemented in Ocaml, as Ocaml do type inference, 
and if we test if s is a member of s in Ocaml (like List.mem s s), the compiler 
will complain that as s is of type 'a, and the second s should be 'a list 
rather than 'a. This leads to an type error, which means self_member cannot be implemented. *)

(* Q6: compute fixed point, compute the fixed point of a function *)
let rec computed_fixed_point eq f x = 
    if (eq x (f x)) then x else (computed_fixed_point eq f (f x));;


(* a symbol has type N or T *)
type ('nonterminal, 'terminal) symbol =
      | N of 'nonterminal
      | T of 'terminal;;

(* extract symbols of type nonterminal from a list *)
let rec extract l = match l with
  [] -> [] 
  | head :: tail -> (match head with 
  N a -> (a :: (extract tail))
  | T _ -> (extract tail));;

(* get reachable symbols starting from given grammar, note
that the checking is not enough since the rules are checked 
from top to bottom, so the order may not be optimal, need 
to compute fix point to make it more robust *)
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

(* test whether the second elements of two tuples are the same *)
let equal_second_element a b = equal_sets (snd a) (snd b);;

(* variant of the computed_fixed_point for Q7 *)
let rec computed_fixed_point_2 eq f (rules, symbols) = 
    if (eq (rules, symbols) (f (rules, symbols))) then (rules, symbols) else
    (computed_fixed_point_2 eq f (rules, (snd (f (rules, symbols)))));;

(* Q7 filter reachable, get reachable symbols, with use of computing
o fixed point to ensure that all the reachable symbols are included *)
let filter_reachable grammar = 
      let start_symbol = (fst grammar) in
      let rules = (snd grammar) in
      let reachable_symbols = (snd (computed_fixed_point_2 equal_second_element 
      get_reachable_symbols (rules, [start_symbol]))) in
      let filtered_rules = List.filter (fun a -> (List.mem (fst a) 
      reachable_symbols)) rules in
      (start_symbol, filtered_rules);;