#lang racket
(provide expr-compare)
(provide (all-defined-out))

(define (lambda? x)
  (if (member x '(lambda λ)) #t #f))

(define (expr-compare x y)
    (cond
        [(equal? x y) x]
        [(and (boolean? x) (boolean? y))
            (if x '% '(not %))]
        [(or (not (list? x)) (not (list? y)))
            (list 'if '% x y)]
        [(and (list? x) (list? y))
            (expr-compare-list x y)]))

(define (expr-compare-list x y)
    (define (expr-compare-lambda x y)
        (define (compare-lambda-helper lmbda)
            (if
                (not (equal? (length (cadr x)) (length (cadr y))))
                    (list 'if '% x y)
                    (expr-parse-lambda (cdr x) (cdr y) lmbda '() '())))
        (cond
            [(equal? (car x) (car y))
                (let ([lmbda (car x)]) (compare-lambda-helper lmbda))]
            [#t (compare-lambda-helper 'λ)]))
    (cond 
        [(not (equal? (length x) (length y))) 
            (list 'if '% x y)]
        [(equal? (length x) (length y))
            (cond 
                [(and (equal? (car x) 'if) (equal? (car y) 'if))
                    (expr-compare-list-body x y)]
                [(or (equal? (car x) 'if) (equal? (car y) 'if))
                    (list 'if '% x y)]
                [(or (equal? (car x) 'quote) (equal? (car y) 'quote))
                    (list 'if '% x y)]
                [(and (lambda? (car x)) (lambda? (car y)))
                    (expr-compare-lambda x y)]
                [(or (lambda? (car x)) (lambda? (car y)))
                    (list 'if '% x y)]
                [#t (expr-compare-list-body x y)])]))

(define (expr-compare-list-body x y)
    (if
        (and (empty? x) (empty? y)) empty
        (let 
            ([remaining_res (expr-compare-list-body (cdr x) (cdr y))])
            (cond
                [(equal? (car x) (car y)) 
                    (cons (car x) remaining_res)]
                [(and (boolean? (car x)) (boolean? (car y)))
                    (cons (if (car x) '% '(not %)) remaining_res)]
                [(and (list? (car x)) (list? (car y)) (equal? (length (car x)) (length (car y))))
                    (cons (expr-compare-list (car x) (car y)) remaining_res)]
                [#t
                    (cons (list 'if '% (car x) (car y)) remaining_res)]))))

(define (concat-syms sym1 sym2)
    (string->symbol (string-append (symbol->string sym1) "!" (symbol->string sym2))))

(define (my-map x y rev-flag)
    (if (and (empty? x) (empty? y)) (hash)
        (let ([cur-map (my-map (cdr x) (cdr y) rev-flag)]
              [hd-x (car x)]
              [hd-y (car y)])
        (if (equal? hd-x hd-y) (hash-set cur-map hd-x hd-y)
            (hash-set cur-map hd-x (if rev-flag (concat-syms hd-y hd-x) (concat-syms hd-x hd-y)))))))

(define (expr-parse-lambda x y lmda x-list y-list)
    (define (combine-lambda-args x y)
    (cond
        [(and (empty? x) (empty? y)) empty]
        [(equal? (car x) (car y)) (cons (car x) (combine-lambda-args (cdr x) (cdr y)))]
        [#t (cons 
            (concat-syms (car x) (car y))
            (combine-lambda-args (cdr x) (cdr y)))]))
    (let ([args-x (car x)]
          [args-y (car y)])
        (list lmda (combine-lambda-args args-x args-y)
        (parse-lambda (cadr x) (cadr y)
            (cons (my-map args-x args-y #f) x-list)
            (cons (my-map args-y args-x #t) y-list)))))

(define (get-symbol x x-list)
        (if (empty? x-list) "Not Found"
            (let ([find-res (hash-ref (car x-list) x "Not Found")])
                (if (equal? find-res "Not Found") 
                    (get-symbol x (cdr x-list)) find-res))))

(define (parse-lambda x y x-list y-list)
        (let ([find-res-x (get-symbol x x-list)]
            [find-res-y (get-symbol y y-list)])
            (let ([res-x (if (equal? find-res-x "Not Found") x find-res-x)]
                [res-y (if (equal? find-res-y "Not Found") y find-res-y)])
                (cond
                    [(equal? res-x res-y) res-x]
                    [(and (boolean? x) (boolean? y)) (if x '% '(not %))]
                    [(and (list? x) (list? y) (equal? (length x) (length y))) (parse-lambda-list x y x-list y-list)]
                    [(and (list? x) (list? y)) (list 'if '% (replace-expr-head x x-list) (replace-expr-head y y-list))]
                    [(or (not (list? x)) (not (list? y)))
                        (list 'if '% 
                            (if (list? x) (replace-expr-head x x-list) res-x) 
                            (if (list? y) (replace-expr-head y y-list) res-y))]))))

(define (parse-lambda-list-body x y x-list y-list) 
    (if (and (empty? x) (empty? y)) empty
        (let ([find-res-x (get-symbol (car x) x-list)]
              [find-res-y (get-symbol (car y) y-list)])
            (let ([res-x (if (equal? find-res-x "Not Found") (car x) find-res-x)]
                  [res-y (if (equal? find-res-y "Not Found") (car y) find-res-y)])
                (if
                    (or (and (not (list? res-x)) (list? res-y)) (and (list? res-x) (not (list? res-y))))
                    (list 'if '% 
                            (if (list? x) (replace-expr-head x x-list) res-x) 
                            (if (list? y) (replace-expr-head y y-list) res-y))
                    (let ([parse-remaining (parse-lambda-list-body (cdr x) (cdr y) x-list y-list)])
                        (cond
                            [(equal? res-x res-y) (cons res-x parse-remaining)]
                            [(and (boolean? (car x)) (boolean? (car y))) 
                                (cons (if (car x) '% '(not %)) parse-remaining)]
                            [(and (list? res-x) (list? res-y) (equal? (length x) (length y))) 
                                (cons (parse-lambda-list (car x) (car y) x-list y-list) parse-remaining)]
                            [(and (list? res-x) (list? res-y)) 
                                (cons (list 'if '% (replace-expr-head (car x) x-list) (replace-expr-head (car y) y-list)) parse-remaining)]
                            [#t (cons (list 'if '% res-x res-y) parse-remaining)])))))))


(define (parse-lambda-list x y x-list y-list)
    (cond 
        [(and (equal? (car x) 'if) (equal? (car y) 'if)) 
            (cons 'if (parse-lambda-list-body (cdr x) (cdr y) x-list y-list))]
        [(or (equal? (car x) 'if) (equal? (car y) 'if))
            (list 'if '% (replace-expr-head x x-list) (replace-expr-head y y-list))]
        [(or (equal? (car x) 'quote) (equal? (car y) 'quote))
            (if (equal? x y) x (list 'if '% 
            (replace-expr-head x x-list) 
            (replace-expr-head y y-list)))]
        [(and (lambda? (car x)) (lambda? (car y)))
            (let ([lmbda (if (equal? (car x) (car y)) (car x) 'λ)])
                (if (equal? (length (cadr x)) (length (cadr y))) 
                    (expr-parse-lambda (cdr x) (cdr y) lmbda x-list y-list)
                    (list 'if '% (replace-expr-head x x-list) (replace-expr-head y y-list))))]
        [(or (lambda? (car x)) (lambda? (car y))) (list 'if '% (replace-expr-head x x-list) (replace-expr-head y y-list))]
        [#t (parse-lambda-list-body x y x-list y-list)]))


(define (replace-expr-head x x-list)
    (cond
        [(empty? x) empty]
        [(equal? (car x) 'quote) x]
        [(boolean? (car x)) (cons (car x) (replace-expr-body (cdr x) x-list))]
        [(equal? (car x) 'if) (cons (car x) (replace-expr-body (cdr x) x-list))]
        [(lambda? (car x)) (cons (car x) (cons (cadr x) (replace-expr-body (cddr x) 
                (cons (my-map (cadr x) (cadr x) #f) x-list))))]
        [(list? (car x) (cons (replace-expr-head (car x) x-list) (replace-expr-body (cdr x) x-list)))]
        [#t (cons
                (if (equal? (get-symbol (car x) x-list) "Not Found") (car x) (get-symbol (car x) x-list))
                (replace-expr-body (cdr x) x-list))]))

(define (replace-expr-body x x-list) 
    (cond 
        [(empty? x) empty]
        [(equal? (car x) 'quote) x]
        [(boolean? (car x)) (cons (car x) (replace-expr-body (cdr x) x-list))]
        [(list? (car x)) (cons (replace-expr-head (car x) x-list) (replace-expr-body (cdr x) x-list))]
        [#t (cons
                (if (equal? (get-symbol (car x) x-list) "Not Found") (car x) (get-symbol (car x) x-list))
                (replace-expr-body (cdr x) x-list))]))


(define (replace-sym old new expr)
    (define (replace e)
        (cond 
            [(list? e) (map replace e)]
            [(equal? e old) new]
            [#t e]
        )
    )
    (replace expr)
)

(define (test-expr-compare x y)
    (let ([cmp-result (expr-compare x y)])
        (let ([expr-x (replace-sym '% #t cmp-result)]
              [expr-y (replace-sym '% #f cmp-result)])
            (if 
                (and (equal? (eval x) (eval expr-x))
                    (equal? (eval y) (eval expr-y)))
                #t #f
            ))))

(define test-expr-x
    '(if (eq? #t ((lambda (a b flag) (eq? a ((λ (c) (if flag (+ 1 c) (- 1 c))) b))) 2 1 #t)) (quote (a b)) (list 'a 'c))
)

(define test-expr-y
    '(if (equal? #t ((λ (c d flag) (equal? c ((λ (e) (if flag (* 1 e) (+ 1 e))) d))) 1 2 #f)) (list 'a 'c) (quote (a b)))
)