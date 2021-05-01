
let rec convert_helper_1 acc l = match l with
| [] -> List.rev acc
| head :: _ -> (
  let current = List.filter (fun a -> fst a = (fst head)) l in
  let remaining = List.filter (fun a -> fst a <> (fst head)) l in
  let this_rule = ((fst head), (List.map (fun a -> (snd a)) current)) in
  convert_helper_1 (this_rule :: acc) remaining)  ;;


let rec find_symbol acc s = match acc with
| [] -> []
| head :: tail -> if (s = (fst head)) then (snd head) else 
find_symbol tail s  ;;

let convert_grammar gram1 = 
  let start_symbol = (fst gram1) in
  let rules = (snd gram1) in
  let compacted_rules = (convert_helper_1 [] rules) in
  (start_symbol, (find_symbol compacted_rules)) ;;

type ('nonterminal, 'terminal) symbol =
    | N of 'nonterminal
    | T of 'terminal  ;;
  
type ('nonterminal, 'terminal) parse_tree =
    | Node of 'nonterminal * ('nonterminal, 'terminal) parse_tree list
    | Leaf of 'terminal ;;

let rec parse_helper tree acc =
  match tree with
  | Leaf l -> l::acc
  | Node (_, next_lev) -> (
      let rec parse_this_level level acc1 =
        match level with
        | [] -> acc1
        | head :: tail -> (
          let temp_acc = parse_helper head [] in
          parse_this_level tail (temp_acc @ acc1)) in
        parse_this_level next_lev acc)  ;;

let parse_tree_leaves tree =
  List.rev (parse_helper tree []) ;;



let match_term t acceptor = function
  | h::s when h = t -> acceptor s
  | _ -> None ;;

let rec match_nonterm prod_rules nt acceptor l =
  let rules_list = prod_rules nt in
    let rec match_rules_list rules acceptor l =
    match rules with
    | [] -> None
    | h::s -> let rec match_rule rule acceptor l =
        match rule with
        | [] -> acceptor l
        | hd::tl -> let acceptorTL = 
        fun frag -> match_rule tl acceptor frag in
          match hd with
          | N non_term -> match_nonterm prod_rules non_term 
          acceptorTL l
          | T term -> match_term term acceptorTL l
        in 
        let try_hd = match_rule h acceptor l in
        match try_hd with
        | Some x -> Some x
        | None -> match_rules_list s acceptor l in
    match_rules_list rules_list acceptor l  ;;

let make_matcher gram = 
  let start_symbol = (fst gram) in
  let produ_fun = (snd gram) in
    match_nonterm produ_fun start_symbol  ;;


let parse_term t acceptor tree = function
  | h::s when h = t -> acceptor tree s
  | _ -> None ;;

let rec parse_nonterm prod_fun nt acceptor acc l = 
  let rules_list = (prod_fun nt) in
  let rec parse_rules_list rules acceptor acc l =
    match rules with
    | [] -> None
    | h::s -> let rec parse_rule rule acceptor acc l = 
      match rule with
      | [] -> acceptor acc l
      | hd::tl -> let acceptorTL =  parse_rule tl acceptor in
        match hd with
        | N nonterm -> parse_nonterm prod_fun nonterm acceptorTL acc l
        | T term -> parse_term term acceptorTL acc l
      in let try_hd = parse_rule h acceptor ((nt, h)::acc) l in
      match try_hd with
      | Some x -> try_hd
      | None -> parse_rules_list s acceptor acc l in
  parse_rules_list rules_list acceptor acc l  ;;


let rec construct_tree derivation = match derivation with
  | [] -> invalid_arg "derivation" (* note that the empty case will be checked ahead *)
  | hd::tl -> 
    let sym = fst hd in
    let current_level = snd hd in
    let rec rhs_to_children path_left cur_level =
    match cur_level with
    | [] -> path_left, []
    | head::tail -> match head with
      | N nonterm -> 
        let sub_tree_res = construct_tree path_left in
        let siblings_trees_res = rhs_to_children (fst sub_tree_res) tail in
        (fst siblings_trees_res), ((snd sub_tree_res)::(snd siblings_trees_res))
      | T term ->
        let trees_res = rhs_to_children path_left tail in
        (fst trees_res), ((Leaf term)::(snd trees_res)) in
    let children_res = rhs_to_children tl current_level in
    (fst children_res), Node (sym, (snd children_res))  ;;

let make_parser gram =
  let parse_accept_empty_suffix tree = function
    | [] -> Some tree
    | _ -> None in
  let make_parser_helper gram frag = 
    let derivation = 
      parse_nonterm (snd gram) (fst gram) parse_accept_empty_suffix [] frag in
    match derivation with
    | Some path when (List.length path) > 0 -> 
        Some (snd (construct_tree (List.rev path)))
    | _ -> None in
  make_parser_helper gram ;;



let rec merge_sorted op a b = match a with
    | [] -> b
    | h::t -> match b with
      | [] -> a
      | hd::tl -> if (op h hd) then h::(merge_sorted op t b)
      else hd::(merge_sorted op a tl);;

  

let rec adjdup l = match l with
| [] -> []
| hd::_ -> let same_as_hd = (List.filter (fun a -> a == hd) l) in
            let remain_tl = (List.filter (fun a -> a <> hd) l) in
            same_as_hd @ adjdup remain_tl;;

let test_l = [7; 6; 7; 8; 8; 4; 10; 4; 3; 5; 1; 2; 7; 7; 10; 9; 8; 5];;

adjdup test_l;;


let rec nonterm_rhs rhs acc =
  match rhs with
  | [] -> acc
  | hd::tl -> match hd with
    | N nonterm -> if List.mem nonterm acc then 
      (nonterm_rhs tl acc) else (nonterm_rhs tl (nonterm::acc))
    | T term -> (nonterm_rhs tl acc)


let rec gsyms_helper gram acc =
  match gram with
  | [] -> acc
  | hd::tl -> let new_acc = nonterm_rhs (snd hd) acc in
  if List.mem (fst hd) new_acc then 
    (gsyms_helper tl new_acc) else
    (gsyms_helper tl ((fst hd)::new_acc))

let gsyms gram = gsyms_helper gram []
