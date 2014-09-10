;;; Function properties.

;;; Commentary:

;; This module has code to note properties of functions.  The
;; properties in question are those which are of interest to the
;; compiler, and which are considered immutable -- currently it is
;; only possible for the compiler to handle properties of functions
;; that the user cannot reasonably redefine.

;;; Code:

(defun elcomp-declare (func &rest props)
  "Apply PROPS, a plist of attributes, to FUNC, a symbol.

Defined properties are:

  :elcomp-const t|nil        If t, FUNC only examines its arguments, not memory.
  :elcomp-type TYPE          The return type of FUNC.
  :elcomp-simple-numeric t|n If t, FUNC is a simple numeric function.  This

                             means that it accepts a number of
                             integer, marker, or float arguments,
                             and that the type of the result
                             follows the usual contagion rules."
  ;; add more?
  ;; :pure - like const but can refer to memory - e.g., car
  ;; :nothrow - can't signal or throw
  ;; :malloc - allocates new object
  ;; :primitive - assume this can never be rewritten, e.g. car
  ;; ... though if a function has any properties then we're already
  ;; assuming that.
  (while props
    (put func (car props) (cadr props))
    (setf props (cddr props))))

(defun elcomp--const-p (func)
  "Return t if FUNC can be considered 'const'."
  (get func :elcomp-const))

(defun elcomp--type (func)
  "Return the type of FUNC, if known, or nil."
  (get func :elcomp-type))

(defun elcomp--simple-numeric-p (func)
  "Return t if FUNC can be considered 'simple-numeric'."
  (get func :elcomp-simple-numeric))

(dolist (func '(+ - * / % 1+ 1- mod max min abs expt))
  (elcomp-declare func :elcomp-const t :elcomp-simple-numeric t))

(dolist (func '(isnan floatp integerp numberp natnump zerop = eql eq equal
		      /= < <= > >=))
  (elcomp-declare func :elcomp-const t :elcomp-type 'boolean))

(dolist (func '(ldexp copysign logb float truncate floor ceiling round
		      ffloor fceiling ftruncate fround
		      sin cos tan asin acos atan exp log
		      sqrt))
  (elcomp-declare func :elcomp-const t :elcomp-type 'float))

(dolist (func '(lsh ash logand logior logxor lognot byteorder))
  (elcomp-declare func :elcomp-const t :elcomp-type 'integer))

(elcomp-declare 'cons :elcomp-type 'list)
