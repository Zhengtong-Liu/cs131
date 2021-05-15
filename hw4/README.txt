Test the performance of kenken and plain_kenken:

| ?- statistics, fd_set_vector_max(255), kenken_testcase4(N, C), 
   kenken(N, C, T), statistics.

Useful output:

Memory               limit         in use            free

   trail  stack      16383 Kb            5 Kb        16378 Kb
   cstr   stack      16383 Kb           11 Kb        16372 Kb
   global stack      32767 Kb            4 Kb        32763 Kb
   local  stack      16383 Kb            3 Kb        16380 Kb
   atom   table      32768 atoms      1800 atoms     30968 atoms

Times              since start      since last

   user   time       0.024 sec       0.000 sec
   system time       0.000 sec       0.000 sec
   cpu    time       0.024 sec       0.000 sec
   real   time      67.180 sec       0.000 sec

| ?- statistics, kenken_testcase4(N, C), plain_kenken(N, C, T), statistics.

Useful output:

Memory               limit         in use            free

   trail  stack      16383 Kb            0 Kb        16383 Kb
   cstr   stack      16384 Kb            0 Kb        16384 Kb
   global stack      32767 Kb            8 Kb        32759 Kb
   local  stack      16383 Kb            6 Kb        16377 Kb
   atom   table      32768 atoms      1800 atoms     30968 atoms

Times              since start      since last

   user   time       0.072 sec       0.048 sec
   system time       0.000 sec       0.000 sec
   cpu    time       0.072 sec       0.048 sec
   real   time     215.003 sec       0.084 sec

Discussion on the memory (in use):
From the statistics collected, we see that kenken uses 4 Kb in terms of
the global stack and 3 Kb in terms of the local stack while plain_kenken 
uses 8 Kb in terms of the global stack and 6 Kb in terms of the local stack,
so plain_kenken uses twice as much as the heap memory (global stack) and the 
control stack memory (local stack) used by kenken. Note that cstr stack denotes
the finite domain constraint stack, which stores FD variables and constraints, 
and kenken uses 11 Kb memory in this stack, while plain_kenken uses none. This
information is consistent with the requirements that kenken can use the FD 
solver while plain_kenken cannot. 

Discussion about the speed (since last):
Note that kenken uses very little user CPU time, system CPU time, total
CPU time and real time, meaning kenken solved the problem really fast.
In constrast, plain_kenken uses about 0.048 seconds user
CPU time, very little system CPU time, and 0.048 seconds 
in terms of the CPU time and 0.084 seconds in terms of the real time 
to run this 4 x 4 test case. This data shows that 
kenken runs much faster than plain_kenken. In fact, when testing on 6 x 6
matrices, kenken took little time to solve it and plain_kenken seemed to
be stuck. This constrast also confirmed that kenken performed much better
than plain_kenken, especially as the size of the matrix to solve is getting
larger. 


Design of the no-op kenken:
    interface: noop_kenken(N, C, T, O)
    N -- a nonnegative integer specifying the number of cells 
        on each side of the KenKen square.
    C -- a list of numeric cage constraints (without operations).
    T -- a list of list of integers. All the lists have length N. 
        This represents the N×N grid.
    O -- operations deduced from the numeric cage constraints. 
    The operations are stored in a NxN grid O. If a position p is
    included in some numeric constraint, the operation deduced
    from the numeric constraint should be stored at position p
    of the NxN grid O.

    Example 1:
    noop_kenken_testcase_1(
        4,
        [
        (6, [[1|1], [1|2], [2|1]]),
        (96, [[1|3], [1|4], [2|2], [2|3], [2|4]]),
        (1, [3|1], [3|2]),
        (1, [4|1], [4|2]),
        (8, [[3|3], [4|3], [4|4]]),
        (2, [[3|4]])
        ]
    ).

   Then the query:
       | ?- noop_kenken_testcase_1(N, C), noop_kenken(N, C, T, O).
   has one possible solution:
    
    O = [[+,+,*,*],[+,*,*,*],[-,-,*,+],[-,-,+,+]]
    T = [[1,2,3,4],[3,4,2,1],[4,3,1,2],[2,1,4,3]]

   Example 2:
   noop_kenken_testcase_2(
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

   Then the query:
      | ?- noop_kenken_testcase_2(N, C), noop_kenken(N, C, T, O).
   should output:

   O = [[-,-,*,*],[-,*,*,*],[-,+,*,+],[+,+,+,+]]
   T = [[1,2,3,4],[2,1,4,3],[3,4,1,2],[4,3,2,1]]

Remark to the noop_kenken:
    Aside from figuring out the soduku cell problem and 
    satisfying the numeric constraints, noop_kenken also
    needs to figure out the operations associated with the
    constraints. The implementation might try different
    operations on a numeric constraints list to achieve that.
    Also, if the pattern of constraint of / and - is still different
    with * and + so that the constraint of / and - is of the pattern
    (D, J, K), where D (or Q) is the difference (or quotient) and J, K
    are the positions, while the constraint of + and + is of the 
    pattern (S, L), where S (or P) is the sum (or product) and L is
    the positions list, it might help to simplify the problem. 
    noop_kenken can distinguish the constraints of + and * from those
    of / and - by matching to different terms. 
