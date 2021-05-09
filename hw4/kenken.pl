sudoku_cell(N, X) :-
    % array size limits
    len_row(X, N),
    len_col(X, N),
    % finish domain limits
    within_domain(X, N),
    maplist(fd_all_different, X),
    transpose(X, T),
    maplist(fd_all_different, T),
    maplist(fd_labeling, X).

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

check_sum_helper(0, [], _).
check_sum_helper(Sum, [Hd|Tl], M) :-
    Sum > 0,
    [R|C] = Hd, nth(R, M, Row), nth(C, Row, E),
    Rem is Sum - E,
    check_sum_helper(Rem, Tl, M).

check_sum(Expr, M) :-
    +(S, L) = Expr,
    check_sum_helper(S, L, M).

check_mult_helper(1, [], _).
check_mult_helper(Product, [Hd|Tl], M) :-
    Product > 1,
    [R|C] = Hd, nth(R, M, Row), nth(C, Row, E),
    Rem is Product / E,
    check_mult_helper(Rem, Tl, M).

check_mult(Expr, M) :-
    *(P, L) = Expr,
    check_mult_helper(P, L, M).

check_diff(Expr, M) :-
    -(D, J, K) = Expr,
    [R1|C1] = J, [R2|C2] = K,
    nth(R1, M, Row1), nth(C1, Row1, E1),
    nth(R2, M, Row2), nth(C2, Row2, E2),
    (D is E1 - E2; D is E2 - E1).

check_quot(Expr, M) :-
    /(Q, J, K) = Expr,
    [R1|C1] = J, [R2|C2] = K,
    nth(R1, M, Row1), nth(C1, Row1, E1),
    nth(R2, M, Row2), nth(C2, Row2, E2),
    (Q is E1 / E2; Q is E2 / E1).

check_cage([], _).
check_cage([Hd|Tl], M) :-
    (check_sum(Hd, M); check_mult(Hd, M); check_diff(Hd, M); check_quot(Hd, M)),
    check_cage(Tl, M).

kenken(N, C, T) :-
    sudoku_cell(N, T),
    check_cage(C, T).


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