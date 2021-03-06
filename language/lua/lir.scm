;;  Copyright (C) 2016
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

(define-module (language lua lir)
  #:use-module (language lua types)
  #:use-module (ice-9 match)
  #:export (lir->ast
            ast->lir))

;; LIR stands for Lua IR, a simple typed IR for optimizing.

(define (ast->lir ast)
  (match ast
    ;; Literals
    ('(marker nil)
     (gen-nil))
    ('(boolean true)
     (gen-true))
    ('(boolean false)
     (gen-false))
    (`(number ,x)
     (gen-number x))
    (`(string ,x)
     (gen-string x))

    ;; variables
    (`(variable ,x)
     `(variable ,(ast->lir x)))

    (`(store ,x ,v)
     `(store ,x ,(ast->lir v)))

    ;; scope and statment
    (('scope rest)
     `(scope ,(ast->lir rest)))
    (('begin form ...)
     `(begin ,(ast->lir form)))
    (('begin forms ...)
     `(begin ,@(map (lambda (x) (ast->lir x)) forms)))
    (('if cnd 'then b1)
     `(if ,(ast->lir cnd) then ,(ast->lir b1)))
    (('if cnd 'then b1 else b2)
     `(if ,(ast->lir cnd)
          then
          ,(ast->lir b1)
          else
          ,(ast->lir b2)))
    (('if cnd 'then b1 'elseif c2 'then b2 . rest)
     (define (-> x)
       (match x
         (() #t)
         (('elseif c 'then b . r)
          `(elseif ,(ast->lir c)
                   then
                   ,(ast->lir b)
                   (-> r)))
         (else error ast->lir "BUG: Shouldn't be here!" x)))
     `(if ,(ast->lir cnd)
          then
          ,(ast->lir b1)
          elseif
          ,(ast->lir c2)
          then
          ,(ast->lir b2)
          (-> x)))

    ;; arithmatic op
    (`(add ,x ,y)
     `(add ,(ast->lir x) ,(ast->lir y)))
    (`(minus ,x ,y)
     `(minus ,(ast->lir x) ,(ast->lir y)))
    (`(multi ,x ,y)
     `(multi ,(ast->lir x) ,(ast->lir y)))
    (`(div ,x ,y)
     `(div ,(ast->lir x) ,(ast->lir y)))
    (`(mod ,x ,y)
     `(mod ,(ast->lir x) ,(ast->lir y)))
    (`(expt ,x ,y)
     `(expt ,(ast->lir x) ,(ast->lir y)))

    ;; logical op
    (`(lt ,x ,y)
     `(lt ,(ast->lir x) ,(ast->lir y)))
    (`(gt ,x ,y)
     `(gt ,(ast->lir x) ,(ast->lir y)))
    (`(eq ,x ,y)
     `(eq ,(ast->lir x) ,(ast->lir y)))
    (`(geq ,x ,y)
     `(geq ,(ast->lir x) ,(ast->lir y)))
    (`(leq ,x ,y)
     `(leq ,(ast->lir x) ,(ast->lir y)))

    ;; functions
    (`(func-call (id ,func) (args ,args))
     `(func-call (id ,func) (arts ,(map ast->lir args))))
    (('func-def `(id ,func) ('params p ...) body)
     `(func-def (id ,func) (params ,p) ,(ast->lir body)))
    (('anon-func-def params body)
     `(anon-func-def ,params ,body))

    (else (error ast->lir "invalid ast" ast))))

(define (lir->ast lir)
  (match lir
    ;; Literals
    ((? <lua-nil>?)
     '(marker nil))     
    ((? lua-true?)
     '(boolean true))
    ((? lua-false?)
     '(boolean false))
    ((? <lua-number>? num)
     `(number ,(<lua-type>-value num)))
    ((? <lua-string>? str)
     `(string ,(<lua-type>-value str)))

    ;; variables
    (`(variable ,x)
     `(variable ,(lir->ast x)))

    (`(store ,x ,v)
     `(store ,x ,(lir->ast v)))

    ;; scope and statment
    (('scope rest)
     `(scope ,(lir->ast rest)))
    (('begin form ...)
     `(begin ,(lir->ast form)))
    (('begin forms ...)
     `(begin ,@(map (lambda (x) (lir->ast x)) forms)))
    (('if cnd 'then b1)
     `(if ,(lir->ast cnd) then ,(lir->ast b1)))
    (('if cnd 'then b1 else b2)
     `(if ,(lir->ast cnd)
          then
          ,(lir->ast b1)
          else
          ,(lir->ast b2)))
    (('if cnd 'then b1 'elseif c2 'then b2 . rest)
     (define (-> x)
       (match x
         (() #t)
         (('elseif c 'then b . r)
          `(elseif ,(lir->ast c)
                   then
                   ,(lir->ast b)
                   (-> r)))
         (else error lir->ast "BUG: Shouldn't be here!" x)))
     `(if ,(lir->ast cnd)
          then
          ,(lir->ast b1)
          elseif
          ,(lir->ast c2)
          then
          ,(lir->ast b2)
          (-> x)))

    ;; arithmatic op
    (`(add ,x ,y)
     `(add ,(lir->ast x) ,(lir->ast y)))
    (`(minus ,x ,y)
     `(minus ,(lir->ast x) ,(lir->ast y)))
    (`(multi ,x ,y)
     `(multi ,(lir->ast x) ,(lir->ast y)))
    (`(div ,x ,y)
     `(div ,(lir->ast x) ,(lir->ast y)))
    (`(mod ,x ,y)
     `(mod ,(lir->ast x) ,(lir->ast y)))
    (`(expt ,x ,y)
     `(expt ,(lir->ast x) ,(lir->ast y)))

    ;; logical op
    (`(lt ,x ,y)
     `(lt ,(lir->ast x) ,(lir->ast y)))
    (`(gt ,x ,y)
     `(gt ,(lir->ast x) ,(lir->ast y)))
    (`(eq ,x ,y)
     `(eq ,(lir->ast x) ,(lir->ast y)))
    (`(geq ,x ,y)
     `(geq ,(lir->ast x) ,(lir->ast y)))
    (`(leq ,x ,y)
     `(leq ,(lir->ast x) ,(lir->ast y)))

    ;; functions
    (`(func-call (id ,func) (args ,args))
     `(func-call (id ,func) (arts ,(map lir->ast args))))
    (('func-def `(id ,func) ('params p ...) body)
     `(func-def (id ,func) (params ,p) ,(lir->ast body)))
    (('anon-func-def params body)
     `(anon-func-def ,params ,body))

    (else (error lir->ast "invalid lir" lir))))
