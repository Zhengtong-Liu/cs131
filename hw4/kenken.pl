% Note:
% Some of the codes are from CS131 code help repo: 
% https://github.com/CS131-TA-team/UCLA_CS131_CodeHelp
% including len_col, within_domain, transpose, list_firsts_rests.
% One function, plain_all_unique, is from the Discussion 1B Slides
% Thanks the TAs team so much for help
% I write some comments for these methods to make sure I understand them myself

% Performance comparison and noop_kenken design is in README.txt


% Make sure the matrix X has N columns.
% Base case: If the matrix is empty, then any numbers filled in the second
% term is valid;
% Recursive step: make sure that each row has N elements, so the matrix
% in total has N columns. Do this recursively, make sure the head row
% has N elements, and check if the remaining tail matrix has N columns.
len_col([], _).
len_col([HD | TL], N) :-
    length(HD, N),
    len_col(TL, N).

% Make sure the elements in this array are within the domain (1 ~ N).
% Base case: empty array is within any domain.
% Recursive step: make sure the head element is within the domain (1 ~ N);
% then check if the elements of the remaining array are within the domain.
within_domain([], _).
within_domain([HD | TL], N) :-
    fd_domain(HD, 1, N),
    within_domain(TL, N).

% Check if the first matrix is the tranpose of the second one.
% Base case: empty matrix is the transpose of itself
% Recursive step: check the two matrices are tranposes of each other
% using the transpose predicate with three terms.
transpose([], []).
transpose([F|Fs], Ts) :-
    transpose(F, [F|Fs], Ts).


% terms in order: matrix T (matched to head and tail), matrix T, T tranpose 
% Base case: empty matrix transpose
% Recursive step:
% Check that the first row of T_transpose is the first column of T.
% Check that the remaining rows of T_tranpose are the remaining rows of T.
% Separation of the first and the remaing cols are checked by lists_first_rests
transpose([], _, []).
transpose([_|Rs], Ms, [Ts|Tss]) :-
        lists_firsts_rests(Ms, Ts, Ms1),
        transpose(Rs, Ms1, Tss).

% Separate the matrix into two matrices vertically: first column and remaining
% terms in order: A = B | C, B, C (B is the first col)
% Base case: empty matrix separation.
% Recursive step: 
% A is parsed row by row each time
% B is composed of the first element in the first row of A and
% the first cols of the remaining rows
% C is composed of the remaining elements in the first row of A and
% the tail cols of the remaining rows
lists_firsts_rests([], [], []).
lists_firsts_rests([[F|Os]|Rest], [F|Fs], [Os|Oss]) :-
        lists_firsts_rests(Rest, Fs, Oss).

% get the element E in matrix M at position Coord
get_element(Coord, E, M) :-
    [R|C] = Coord, nth(R, M, Row), nth(C, Row, E).

% check constraints in the cage
% first two are the helper functions for sum and mult
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

% check the constraints in order: sum, mult, diff, quot
% the second term is the pattern of constraints
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

% first check that X is a N x N matrix;
% then check all the elements in X are within the domain (1 ~ N);
% then make sure elements within each row are unique;
% require T to be transpose of X;
% make sure elements within each row are unique,
% in this way, we make sure each row, each col has distinct numbers from 1 to N;
% check the constraints (use the idea of partially applying a predicate);
% fd_labeling to make prolog to instantiate
kenken(N, C, T) :-
    length(X, N),
    len_col(X, N),
    within_domain(X, N),
    maplist(fd_all_different, X),
    transpose(X, T),
    maplist(fd_all_different, T),
    maplist(check_constrain(T), C),
    maplist(fd_labeling, X).


%% plain version
% change the order to check the length of an array to allow for partially application
plain_len_row(N, M) :-
    length(M, N).

% check that each row has N elements to check the matrix has N columns
plain_len_col(N, M) :-
    maplist(plain_len_row(N), M).

% check whether an element E is within the domain 1 ~ N
% first construct a list of integers from 1 to N
% then check whether E is a member of this list L
plain_within_domain(N, E) :-
    findall(X, between(1, N, X), L),
    member(E, L).

% check whether elements of a list are unique.
% Base case: empty list contains unique elements;
% Recursive step: check that head is not in the tail;
% then ensure the tail list contains unqiue elements
plain_all_unique([]).
plain_all_unique([Hd|Tl]) :-
    member(Hd, Tl), !, fail.
plain_all_unique([_|Tl]) :-
    plain_all_unique(Tl).

% make sure the elements of a list are within the domain
% and are all unique
plain_all_different(N, L) :-
    maplist(plain_within_domain(N), L),
    plain_all_unique(L).

% check constraints, similar as above, but use is/1 instead of '#='
plain_check_sum_helper(0, [], _).
plain_check_sum_helper(Sum, [Hd|Tl], M) :-
    get_element(Hd, E, M),
    Rem is (Sum - E),
    plain_check_sum_helper(Rem, Tl, M).

plain_check_mult_helper(1.0, [], _).
plain_check_mult_helper(Product, [Hd|Tl], M) :-
    get_element(Hd, E, M),
    Rem is (Product / E),
    plain_check_mult_helper(Rem, Tl, M).

plain_check_constrain(M, +(S, L)) :-
    plain_check_sum_helper(S, L, M).

plain_check_constrain(M, *(P, L)) :-
    plain_check_mult_helper(P, L, M).

plain_check_constrain(M, -(D, J, K)) :-
    get_element(J, E1, M), get_element(K, E2, M),
    ((D is (E1 - E2)); (D is (E2 - E1))).

plain_check_constrain(M, /(Q, J, K)) :-
    get_element(J, E1, M), get_element(K, E2, M),
    ((E1 is (Q * E2)); (E2 is (Q * E1))).

% first make sure X is N x N;
% make sure T is the transpose of X
% note the order is changed, because we need cheap checks at first
% instead of instantiations (without finite domain solver, all the
% range would be instantiated)
% check T has 1 ~ N in each col and row as before
% check T satisfies the constraints
plain_kenken(N, C, T) :-
    plain_len_row(N, X),
    plain_len_col(N, X),
    transpose(X, T),
    maplist(plain_all_different(N), X),
    maplist(plain_all_different(N), T),
    maplist(plain_check_constrain(T), C).


kenken_testcase1(
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


kenken_testcase2(
    4,
    [
    +(6, [[1|1], [1|2], [2|1]]),
    *(96, [[1|3], [1|4], [2|2], [2|3], [2|4]]),
    -(1, [3|1], [3|2]),
    -(1, [4|1], [4|2]),
    +(8, [[3|3], [4|3], [4|4]]),
    *(2, [[3|4]])
    ]
).

kenken_testcase3(
    2,
    []
).

kenken_testcase4(
   4, 
   [
      -(1, [1|1], [1|2]),
      *(36, [[1|3], [1|4], [2|4]]),
      -(1, [2|1], [3|1]),
      *(4, [[2|2], [2|3], [3|3]]),
      +(11, [[3|2], [4|1], [4|2]]),
      +(5, [[3|4], [4|3], [4|4]])
   ]
).

/*
output of 
    | ?- kenken_testcase1(N, C), kenken(N, C, T).

    T = [[5,6,3,4,1,2],[6,1,4,5,2,3],[4,5,2,3,6,1],[3,4,1,2,5,6],[2,3,6,1,4,5],[1,2,5,6,3,4]]
    (same as the answer in the spec)


output of 
    | ?- kenken_testcase2(N, C), kenken(N, C, T).

    T = [[1,2,3,4],[3,4,2,1],[4,3,1,2],[2,1,4,3]]
        [[1,2,4,3],[3,4,2,1],[4,3,1,2],[2,1,3,4]]
        [[3,2,4,1],[1,4,2,3],[4,3,1,2],[2,1,3,4]]
        [[2,1,3,4],[3,4,2,1],[4,3,1,2],[1,2,4,3]]
        [[2,1,4,3],[3,4,2,1],[4,3,1,2],[1,2,3,4]]
        [[3,1,2,4],[2,4,3,1],[4,3,1,2],[1,2,4,3]]
    (same as the answer in the spec, in different order)

output of 
    | ?- kenken_testcase2(N, C), plain_kenken(N, C, T).

    T = [[1,2,3,4],[3,4,2,1],[4,3,1,2],[2,1,4,3]]
        [[1,2,4,3],[3,4,2,1],[4,3,1,2],[2,1,3,4]]
        [[2,1,3,4],[3,4,2,1],[4,3,1,2],[1,2,4,3]]
        [[2,1,4,3],[3,4,2,1],[4,3,1,2],[1,2,3,4]]
        [[3,2,4,1],[1,4,2,3],[4,3,1,2],[2,1,3,4]]
        [[3,1,2,4],[2,4,3,1],[4,3,1,2],[1,2,4,3]]

output of
    | ?- kenken_testcase3(N, C), kenken(N, C, T).

    (also
    | ?- kenken_testcase3(N, C), plain_kenken(N, C, T).)

    T = [[1,2],[2,1]] 
        [[2,1],[1,2]]

output of
    | ?- kenken_testcase4(N, C), kenken(N, C, T).

    (aslo 
    | ?- kenken_testcase4(N, C), plain_kenken(N, C, T).)

    T = [[1,2,3,4],[2,1,4,3],[3,4,1,2],[4,3,2,1]]
*/
