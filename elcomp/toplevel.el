;;; toplevel.el --- compiler top level.  -*- lexical-binding:t -*-

;;; Commentary:

;; Top level interface to compiler.

;;; Code:

(require 'elcomp/coalesce)
(require 'elcomp/cmacros)
(require 'elcomp/cprop)
(require 'elcomp/dom)
(require 'elcomp/eh-cleanup)
(require 'elcomp/jump-thread)
(require 'elcomp/ssa)
(require 'elcomp/typeinf)
(require 'bytecomp)

(defun elcomp--extract-defun (compiler form)
  (unless (eq 'defun (car form))
    (error "not a defun"))
  (setf (elcomp--defun compiler)
	(list (cadr form) (cl-caddr form)))
  (setf form (cl-cdddr form))
  ;; The doc string.
  (if (stringp (car form))
      (progn
	(setf (elcomp--defun compiler)
	      (nconc (elcomp--defun compiler) (list (car form))))
	(setf form (cdr form)))
    (setf (elcomp--defun compiler) (nconc (elcomp--defun compiler) nil)))
  ;; Skip declarations.
  (while (and (consp (car form))
	      (eq (caar form) 'declare))
    (setf form (cdr form)))
  ;; Interactive spec.
  (if (and (consp (car form))
	   (eq (caar form) 'interactive))
      (progn
	(setf (elcomp--defun compiler)
	      (nconc (elcomp--defun compiler) (list (cl-cadar form))))
	(setf form (cdr form)))
    (setf (elcomp--defun compiler) (nconc (elcomp--defun compiler) nil)))
  (cons 'progn form))

(defun elcomp--optimize (compiler)
  (elcomp--thread-jumps-pass compiler nil)
  (elcomp--eh-cleanup-pass compiler)
  (elcomp--coalesce-pass compiler)
  (elcomp--compute-dominators compiler)	; don't really need this right now
  (elcomp--into-ssa-pass compiler)
  (elcomp--cprop-pass compiler)
  (elcomp--thread-jumps-pass compiler t)
  (elcomp--coalesce-pass compiler)
  (elcomp--dce-pass compiler)
  (elcomp--infer-types-pass compiler))

;; See bug #18971.
(defvar byte-compile-free-assignments)
(defvar byte-compile-free-references)
(defvar byte-compile--outbuffer)

(defun elcomp--translate (unit form)
  (byte-compile-close-variables
   (let* ((byte-compile-macro-environment
	   (append elcomp--compiler-macros
		   byte-compile-macro-environment))
	  (compiler (make-elcomp))
	  (result-var (elcomp--new-var compiler)))
     (puthash form compiler (elcomp--compilation-unit-defuns unit))
     (setf (elcomp--unit compiler) unit)
     (setf (elcomp--entry-block compiler) (elcomp--label compiler))
     (setf (elcomp--current-block compiler) (elcomp--entry-block compiler))
     (setf form (elcomp--extract-defun compiler form))
     (elcomp--linearize
      compiler
      (byte-optimize-form (macroexpand-all form
					   byte-compile-macro-environment))
      result-var)
     (elcomp--add-return compiler result-var)
     (elcomp--optimize compiler))))

(defun elcomp--translate-all (unit)
  (while (elcomp--compilation-unit-work-list unit)
    (let ((form (pop (elcomp--compilation-unit-work-list unit))))
      (elcomp--translate unit form))))

(defun elcomp--plan-to-compile (unit form)
  (unless (gethash form (elcomp--compilation-unit-defuns unit))
    (puthash form t (elcomp--compilation-unit-defuns unit))
    (push form (elcomp--compilation-unit-work-list unit))))

(declare-function elcomp--pp-unit "elcomp/comp-debug")

(defun elcomp--do (form-or-forms &optional backend)
  (unless backend
    (setf backend #'elcomp--pp-unit))
  (let ((buf (get-buffer-create "*ELCOMP*")))
    (with-current-buffer buf
      (erase-buffer)
      ;; Use "let*" so we can hack debugging prints into the compiler
      ;; and have them show up in the temporary buffer.
      (let* ((standard-output buf)
	     (unit (make-elcomp--compilation-unit)))
	(if (memq (car form-or-forms) '(defun lambda))
	    (elcomp--plan-to-compile unit form-or-forms)
	  (dolist (form form-or-forms)
	    (elcomp--plan-to-compile unit form)))
	(elcomp--translate-all unit)
	(funcall backend unit))
      (pop-to-buffer buf))))

(provide 'elcomp/toplevel)

;;; toplevel.el ends here
