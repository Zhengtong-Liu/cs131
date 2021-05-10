len_row(X, N) :-
    length(X, N).

len_col([], _).
len_col([HD | TL], N) :-
    length(HD, N),
    len_col(TL, N).

within_domain([], _).
within_domain([HD | TL], N) :-
    fd_domain(HD, 1, N),
    within_domain(TL, N).

% https://stackoverflow.com/questions/4280986/how-to-transpose-a-matrix-in-prolog
transpose([], []).
transpose([F|Fs], Ts) :-
    transpose(F, [F|Fs], Ts).

transpose([], _, []).
transpose([_|Rs], Ms, [Ts|Tss]) :-
        lists_firsts_rests(Ms, Ts, Ms1),
        transpose(Rs, Ms1, Tss).

lists_firsts_rests([], [], []).
lists_firsts_rests([[F|Os]|Rest], [F|Fs], [Os|Oss]) :-
        lists_firsts_rests(Rest, Fs, Oss).

get_element(Coord, E, M) :-
    [R|C] = Coord, nth(R, M, Row), nth(C, Row, E).


check_sum_helper(0, [], _).
check_sum_helper(Sum, [Hd|Tl], M) :-
    get_element(Hd, E, M),
    Rem #= Sum - E,
    check_sum_helper(Rem, Tl, M).

check_mult_helper(1, [], _).
check_mult_helper(Product, [Hd|Tl], M) :-
    get_element(Hd, E, M),
    Rem #= Product / E,
    check_mult_helper(Rem, Tl, M).

check_constrain(M, +(S, L)) :-
    check_sum_helper(S, L, M).

check_constrain(M, *(P, L)) :-
    check_mult_helper(P, L, M).

check_constrain(M, -(D, J, K)) :-
    get_element(J, E1, M), get_element(K, E2, M),
    ((D #= E1 - E2); (D #= E2 - E1)).

check_constrain(M, /(Q, J, K)) :-
    get_element(J, E1, M), get_element(K, E2, M),
    ((Q #= E1 / E2); (Q #= E2 / E1)).

kenken(N, C, T) :-
    len_row(X, N),
    len_col(X, N),
    within_domain(X, N),
    maplist(fd_all_different, X),
    transpose(X, T),
    maplist(fd_all_different, T),
    maplist(check_constrain(T), C),
    maplist(fd_labeling, X).


% plain_all_different(L) :-
%     length(L, Length),
%     sort(L, L_ordered),
%     length(L_ordered, Length_ordered),
%     Length == Length_ordered.

% plain_all_unique([]).
% plain_all_unique([Hd|Tl]) :-
%     member(Hd, Tl), !, fail.
% plain_all_unique([_|Tl]) :-
%     plain_all_unique(Tl).

% plain_within_domain(_, []).
% plain_within_domain(N, [Hd|Tl]) :-
%     length(Hd, N),
%     maplist(between(1, N), Hd),
%     plain_within_domain(N, Tl).

plain_get_element([C|R], E, M) :-
    nth(R, M, Row), nth(C, Row, E).

plain_range(N, L) :-
    findall(X, between(1, N, X), L).

plain_within_domain(N, E) :-
    plain_range(N, L),
    member(E, L).

plain_len_row(N, M) :-
    length(M, N).

plain_all_unique(L) :-
    length(L, L1),
    sort(L, L_sorted),
    length(L_sorted, L2),
    (L1 == L2).

plain_all_different(N, M) :-
    maplist(plain_within_domain(N), M),
    plain_all_unique(M).


plain_check_sum_helper(0, [], _).
plain_check_sum_helper(Sum, [Hd|Tl], M) :-
    plain_get_element(Hd, E, M),
    Rem is (Sum - E),
    plain_check_sum_helper(Rem, Tl, M).

plain_check_mult_helper(1.0, [], _).
plain_check_mult_helper(Product, [Hd|Tl], M) :-
    plain_get_element(Hd, E, M),
    Rem is (Product / E),
    plain_check_mult_helper(Rem, Tl, M).

plain_check_constrain(M, +(S, L)) :-
    plain_check_sum_helper(S, L, M).

plain_check_constrain(M, *(P, L)) :-
    plain_check_mult_helper(P, L, M).

plain_check_constrain(M, -(D, J, K)) :-
    plain_get_element(J, E1, M), plain_get_element(K, E2, M),
    ((D is (E1 - E2)); (D is (E2 - E1))).

plain_check_constrain(M, /(Q, J, K)) :-
    plain_get_element(J, E1, M), plain_get_element(K, E2, M),
    ((E1 is (Q * E2)); (E2 is (Q * E1))).

plain_kenken(N, C, T) :-
    plain_len_row(N, T),
    maplist(plain_len_row(N), T),
    transpose(T, X),
    maplist(plain_all_different(N), T),
    maplist(plain_all_different(N), X),
    maplist(plain_check_constrain(X), C).


within_domain_2(N, Domain) :- 
    findall(X, between(1, N, X), Domain).

fill_2d([], _).
fill_2d([Head | Tail], N) :-
    within_domain_2(N, Domain),
    permutation(Domain, Head),
    fill_2d(Tail, N).

create_grid(Grid, N) :-
    length(Grid, N),
    transpose(Grid, T),
    maplist(unique_list2(N), T),
    fill_2d(Grid, N).


unique_list2(N, L) :-
    unique_list1(L, N).

unique_list1(List, N) :-
	length(List, N),
	elements_between(List, 1, N),
	all_unique(List).

elements_between(List, Min, Max) :-
	maplist(between(Min,Max), List).

within_domain_3(Min, Max, L) :-
    maplist(between(Min, Max), L).

all_unique([]).
all_unique([H|T]) :- exists(H, T), !, fail.
all_unique([H|T]) :- all_unique(T).

exists(X, [X|_]).
exists(X, [_|T]) :-
	exists(X, T).



kenken_testcase(
  6,
  [
   +(11, [[1|1], [2|1]]),
   /(2, [1|2], [1|3]),
   *(20, [[1|4], [2|4]]),
   *(6, [[1|5], [1|6], [2|6], [3|6]]),
   -(3, [2|2], [2|3]),
   /(3, [2|5], [3|5]),
   *(240, [[3|1], [3|2], [4|1], [4|2]]),
   *(6, [[3|3], [3|4]]),
   *(6, [[4|3], [5|3]]),
   +(7, [[4|4], [5|4], [5|5]]),
   *(30, [[4|5], [4|6]]),
   *(6, [[5|1], [5|2]]),
   +(9, [[5|6], [6|6]]),
   +(8, [[6|1], [6|2], [6|3]]),
   /(2, [6|4], [6|5])
  ]
).

ken_answer([[5,6,3,4,1,2],
     [6,1,4,5,2,3],
     [4,5,2,3,6,1],
     [3,4,1,2,5,6],
     [2,3,6,1,4,5],
     [1,2,5,6,3,4]]).


    /* use statistics/0 to measure performance
    Kenken:

    Memory               limit         in use            free

        trail  stack      16383 Kb           11 Kb        16372 Kb
        cstr   stack      16383 Kb           33 Kb        16350 Kb
        global stack      32767 Kb            9 Kb        32758 Kb
        local  stack      16383 Kb            6 Kb        16377 Kb
        atom   table      32768 atoms      1799 atoms     30969 atoms

    Times              since start      since last

        user   time       0.005 sec       0.005 sec
        system time       0.003 sec       0.003 sec
        cpu    time       0.008 sec       0.008 sec
        real   time      11.880 sec      11.880 sec


    */