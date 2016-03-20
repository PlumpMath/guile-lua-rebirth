;;  Copyright (C) 2013,2014,2016
;;      "Mu Lei" known as "NalaGinrut" <NalaGinrut@gmail.com>
;;  This file is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.

;;  This file is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License for more details.

;;  You should have received a copy of the GNU General Public License
;;  along with this program.  If not, see <http://www.gnu.org/licenses/>.

(define-module (language lua impl)
  #:use-module (language lua utils)
  ;;#:use-module (language lua base)
  #:use-module (language lua type-inference)
  #:use-module (language lua optimize)
  #:use-module (language lua types)
  #:use-module (language lua irregex)
  #:use-module (ice-9 match)
  #:export (;; Arith operation
            lua-add lua-minus lua-multi lua-div lua-mod lua-expt
            ;; Logical operation
            lua-lt lua-eq lua-gt lua-geq lua-leq lua-not

            lua-print
            
            is-lua-builtin-func?))

;; TODO: Although it's reasonable to implement new primitives for better type checking,
;;       we have no any chance to do that. Because it's necessary to modify VM to add
;;       new primitives. So we have to convert all the lua-specific-primitives to proper
;;       Guile primitives.

;; NOTE: Cross module function should accept 'value only, not 'tree-il !!!
;;       The reason is that the reduction of 'tree-ill will return 'value eventually, which means
;;       the same cross module function will encounter both 'tree-il (compile time) and
;;       'value (runtime), so we convert all arguments to 'value as convention here!

(define (->stdlib-call lib prim . args)
  `(call (@ (language lua stdlib ,lib) ,prim) ,@(fix-for-cross args)))

;; TODO: how to print table and function?
;; TODO: should accept multi-vals return as arguments.
(define (lua-print x)
  (->stdlib-call 'io 'primitive:lua-print
                 `(lambda () (lambda-case ((() #f #f #f () ()) ,x)))))

(define (emit-tree-il-from-primitive op x y)
  `(call (primitive ,op) ,x ,y))

(define-macro (define-primitive-emitter op)
  `(define (,(symbol-append 'lua-primiitve- op) x y)
     (emit-tree-il-from-primitive ',op x y)))

(define-primitive-emitter +)
(define-primitive-emitter -)
(define-primitive-emitter *)
(define-primitive-emitter /)
(define-primitive-emitter modulo)
(define-primitive-emitter expt)

(define *strnum-re* (string->irregex "0x([a-zA-Z0-9]+)"))
(define (%str->num x)
  ;; NOTE: According to Lua actual activity, if a string can't be converted to a number,
  ;;       say, "0xaz", it will produce a string "0xaz".
  ;; NOTE: Guile will check the type again in the low-level, so we will not check it here.;
  (format #t "str->num: ~a~%" x)
  (match x
   ((? number?) x)
   ((? string? str)
    (let ((sn (irregex-replace *strnum-re* str "#x" 1)))
      (cond
       ((string->number sn) => (lambda (n) `(const ,n)))
       (else x))))
   (else (error str->num "Invalid pattern!" x))))

;; NOTE: Cross module inlined function should accept 'value only, not 'tree-il !!!
(define (str->num x)
  (%str->num (fix-for-cross x)))

;; NOTE: cross module function doesn't need to be tree-il, so the function just return the
;;       common value. Don't convert to (const v)!!!
(define (lua-arith emitter x y)
  (format #t "lua-arith: ~a (~a, ~a)~%" emitter x y)
  (match (get-ast-types x y)
    ('(number number)
     (emitter x y))
    ('(string number)
     (emitter (str->num x) y))
    ('(number string)
     (emitter x (str->num y)))
    ('(string string)
     (emitter (str->num x) (str->num y)))
    ((('lexical name rename) 'number)
     (emitter `(call (@@ (language lua impl) str->num)
                     (lexical ,name ,rename))
              y))
    (('number whatever)
     (emitter x `(call (@@ (language lua impl) str->num)
                       ,y)))
    (('string whatever)
     (emitter (str->num x)
              `(call (@@ (language lua impl) str->num)
                     ,y)))
    ((whatever 'string)
     (emitter `(call (@@ (language lua impl) str->num)
                     ,x)
              (str->num y)))
    ((whatever1 whatever2)
     (emitter `(call (@@ (language lua impl) str->num)
                     ,x)
              `(call (@@ (language lua impl) str->num)
                     ,y)))
    (else (error lua-arith "Fatal: invalid pattern!" (get-ast-types x y)))))

(define (lua-add x y) (lua-arith lua-primiitve-+ x y))
(define (lua-minus x y) (lua-arith lua-primiitve-- x y))
(define (lua-multi x y) (lua-arith lua-primiitve-* x y))
(define (lua-div x y) (lua-arith lua-primiitve-/ x y))
(define (lua-mod x y) (lua-arith lua-primiitve-modulo x y))
(define (lua-expt x y) (lua-arith lua-primiitve-expt x y))

;; return value is guile-boolean 
;; FIXME: add type checking
(define (lua-compare compr x y)
  `(call (primitive ,compr) ,x ,y))

(define (lua-lt x y) (lua-compare '< x y))
(define (lua-eq x y) (lua-compare 'equal? x y))
(define (lua-gt x y) (lua-compare '> x y))
(define (lua-geq x y) (lua-compare '>= x y))
(define (lua-leq x y) (lua-compare '<= x y))
(define (lua-not x) `(call (primitive not) ,x))

;; NOTE: built-in functions are unnecessarily to use a table for fetching, IMO...
(define *built-in-functions*
  `(("print" . ,lua-print)))

(define (is-lua-builtin-func? x)
  (assoc-ref *built-in-functions* x))
