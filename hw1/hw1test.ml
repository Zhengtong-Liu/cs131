

let my_subset_test0 = subset [] []
let my_subset_test1 = subset [] [1; 3]
let my_subset_test2 = subset [1; 1] [1; 3]
let my_subset_test3 = subset [1; 3; 1] [1; 3; 5]
let my_subset_test4 = subset [1; 3; 5] [5; 1; 3]
let my_subset_test5 = not (subset [1; 3] [1])
let my_subset_test6 = subset [] [[]]
let my_subset_test7 = subset [[1]; [2]] [[1]; [2]; [3]]

let my_equal_sets_test0 = equal_sets [] []
let my_equal_sets_test1 = equal_sets [1; 3; 1] [3; 1]
let my_equal_sets_test2 = equal_sets [3; 1] [1; 3; 1]
let my_equal_sets_test3 = not (equal_sets [3; 1; 5] [3; 1; 6])
let my_equal_sets_test4 = not (equal_sets [3; 1; 6] [1])
let my_equal_sets_test5 = not (equal_sets [[]] [[1]])

let my_set_all_union_test0 = equal_sets (set_all_union []) []
let my_set_all_union_test1 = equal_sets (set_all_union [[1; 3]; [3; 4]]) [1; 3; 4]
let my_set_all_union_test2 = equal_sets (set_all_union [[2]; [1; 3]; [2]]) [1; 2; 3]
let my_set_all_union_test3 = 
  equal_sets (set_all_union [[2; 3]; []; [1; 3; 6]; [6; 7]]) [1; 2; 3; 6; 7]
let my_set_all_union_test4 =
  equal_sets (set_all_union [['a'; 'c']; ['b'; 'c']]) ['a'; 'b'; 'c']
let my_set_all_union_test5 =
  equal_sets (set_all_union [['a'; 's']; []; []; ['c']]) ['a'; 'c'; 's']


let my_computed_fixed_point_test0 = 
  computed_fixed_point (=) (fun x -> x/3) 1000 = 0
let my_computed_fixed_point_test1 = 
  computed_fixed_point (=) (fun x -> x *. 3.) 2. = infinity
let my_computed_fixed_point_test2 =
  computed_fixed_point (=) sqrt 100. = 1.
let my_computed_fixed_point_test3 =
  ((computed_fixed_point (fun x y -> abs_float (x -. y) < 2.)
                        (fun x -> x /. 2.)
                        10.)
  = 2.5)
let my_computed_fixed_point_test4 =
  ((computed_fixed_point (fun x y -> (x *. x +. y *. y) < 1.)
                        (fun x -> x /. 2.)
                        10.)
  = 0.625)

type my_test0_nonterminals = 
    | Expr | Num | Binop

let my_test0_rules = 
    [Expr, [N Num];
     Expr, [N Num; N Binop; N Num];
     Binop, [T"+"];
     Binop, [T"-"];
     Num, [T"0"];
     Num, [T"1"];
     Num, [T"2"];
     Num, [T"3"];
     Num, [T"4"];
     Num, [T"5"];
     Num, [T"6"];
     Num, [T"7"];
     Num, [T"8"];
     Num, [T"9"]]
   
let my_test0_grammar = Expr, my_test0_rules

let my_filter_reachable_test0 = 
  filter_reachable my_test0_grammar = my_test0_grammar

let my_filter_reachable_test1 =
  filter_reachable (Expr, List.tl my_test0_rules) = (Expr, List.tl my_test0_rules)

let my_filter_reachable_test2 = 
  filter_reachable (Binop, List.tl (List.tl my_test0_rules)) =
  (Binop, 
   [Binop, [T"+"];
   Binop, [T"-"]])
  
let my_filter_reachable_test3 =
  filter_reachable (Num, my_test0_rules) = 
  (Num,
  [Num, [T"0"];
  Num, [T"1"];
  Num, [T"2"];
  Num, [T"3"];
  Num, [T"4"];
  Num, [T"5"];
  Num, [T"6"];
  Num, [T"7"];
  Num, [T"8"];
  Num, [T"9"]])

let my_filter_reachable_test4 = 
  filter_reachable (Num, List.tl (List.tl my_test0_rules)) =
  (Num,
  [Num, [T"0"];
  Num, [T"1"];
  Num, [T"2"];
  Num, [T"3"];
  Num, [T"4"];
  Num, [T"5"];
  Num, [T"6"];
  Num, [T"7"];
  Num, [T"8"];
  Num, [T"9"]])

type my_test1_nonterminals =
    | Conversation | Sentence | Phrase | Noun | Adjective | Verb

let my_test1_rules =
  [Noun, [T"apple"];
  Noun, [T"bag"];
  Noun, [T"computer"];
  Noun, [T"desk"];
  Noun, [T"earth"];
  Noun, [T"flag"];
  Adjective, [T"big"];
  Adjective, [T"small"];
  Adjective, [T"long"];
  Adjective, [T"short"];
  Adjective, [T"new"];
  Adjective, [T"old"];
  Verb, [T"run"];
  Verb, [T"eat"];
  Verb, [T"has"];
  Verb, [T"hear"];
  Verb, [T"pick"];
  Verb, [T"draw"];
  Phrase, [N Noun];
  Phrase, [N Adjective; N Noun];
  Sentence, [N Verb];
  Sentence, [N Phrase; N Verb];
  Sentence, [N Phrase; N Verb; N Phrase];
  Conversation, [N Sentence];
  Conversation, [N Sentence; T","; N Conversation]]

let my_test1_grammar =
    Conversation, my_test1_rules
    
  
let my_filter_reachable_test5 =
    filter_reachable my_test1_grammar = my_test1_grammar

let my_filter_reachable_test6 =
    filter_reachable (Phrase, my_test1_rules) = 
    (Phrase,   
    [Noun, [T"apple"];
    Noun, [T"bag"];
    Noun, [T"computer"];
    Noun, [T"desk"];
    Noun, [T"earth"];
    Noun, [T"flag"];
    Adjective, [T"big"];
    Adjective, [T"small"];
    Adjective, [T"long"];
    Adjective, [T"short"];
    Adjective, [T"new"];
    Adjective, [T"old"];
    Phrase, [N Noun];
    Phrase, [N Adjective; N Noun]])

let my_filter_reachable_test7 = 
  filter_reachable (Sentence, my_test1_rules) =
    (Sentence, 
    [Noun, [T"apple"];
    Noun, [T"bag"];
    Noun, [T"computer"];
    Noun, [T"desk"];
    Noun, [T"earth"];
    Noun, [T"flag"];
    Adjective, [T"big"];
    Adjective, [T"small"];
    Adjective, [T"long"];
    Adjective, [T"short"];
    Adjective, [T"new"];
    Adjective, [T"old"];
    Verb, [T"run"];
    Verb, [T"eat"];
    Verb, [T"has"];
    Verb, [T"hear"];
    Verb, [T"pick"];
    Verb, [T"draw"];
    Phrase, [N Noun];
    Phrase, [N Adjective; N Noun];
    Sentence, [N Verb];
    Sentence, [N Phrase; N Verb];
    Sentence, [N Phrase; N Verb; N Phrase]])