;;; home-row-numbers.el --- Put numbers on the home row -*- lexical-binding: t; -*-

;;; Copyright 2016 Graham Dobbins

;; Author: Graham Dobbins <gambyte@users.noreply.github.com>
;; Version: 0.1
;; Package-Requires: ((emacs "24.5"))
;; Keywords: convenience, home-row, numbers, prefix-arg

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; This packages allows for conveniently entering numbers for use with
;; universal arguments or for entering into a buffer. It supports both
;; qwerty and dvorak keyboard layouts and has options for using either
;; the home row or a pseudo numpad type layout. Custom keyboard
;; layouts and number orders are also supported.

(eval-when-compile (require 'cl-lib))

(defvar home-row-numbers-qwerty
  '(?a ?s ?d ?f ?g ?h ?j ?k ?l ?\;)
  "list of the qwerty home row keys")

(defvar home-row-numbers-dvorak
  '(?a ?o ?e ?u ?i ?d ?h ?t ?n ?s)
  "list of the dvorak home row keys")

(defvar home-row-numbers-qwerty-numpad
  '(?m ?\, ?\. ?j ?k ?l ?u ?i ?o ?\ )
  "keys forming a numpad under the right hand in qwerty")

(defvar home-row-numbers-dvorak-numpad
  '(?m ?w ?v ?h ?t ?n ?g ?c ?r ?\ )
  "keys forming a numpad under the right hand in dvorak")

(defvar home-row-numbers-norm
  '(?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9 ?0)
  "list of the numbers on the keyboard in normal order")

(defvar home-row-numbers-zero
  '(?0 ?1 ?2 ?3 ?4 ?5 ?6 ?7 ?8 ?9)
  "list of the numbers starting with zero")

(defvar home-row-numbers-prog
  '(?7 ?5 ?3 ?1 ?9 ?0 ?2 ?4 ?6 ?8)
  "list of the numbers on the keyboard in programmer dvorak order")

(defun home-row-numbers-numpad-warning (arg)
  "Issue a warning when ARG is true"
  (when arg
    (warn "home-row-numbers expects the NUMBERS argument to be
    nil when a numpad layout is chosen")))

(defun home-row-numbers-string->char-list (string)
  "Create a list consisting of the characters of STRING"
  (cl-loop for char across string collect char))

(cl-defmacro home-row-numbers-helper (&key (layout 'qwerty)
					   (message t)
					   (print-key ?p)
					   (print-and-continue-key ? )
					   (decimal-key ?\.)
					   (decimal ".")
					   (numbers nil)
					   compile)
  "By implementing the bulk of home-row-numbers as a macro it can
be compiled away if the user byte-compiles their init and all
arguments are constants."
  (ignore compile)
  (cl-assert (stringp decimal) nil
	     "The DECIMAL argument to home-row-numbers should be
	     a string containing the desired decimal character(s)")
  (let ((letters (cond
		  ((eql layout 'qwerty) home-row-numbers-qwerty)
		  ((eql layout 'dvorak) home-row-numbers-dvorak)
		  ((eql layout 'qwerty-numpad)
		   (home-row-numbers-numpad-warning numbers)
		   home-row-numbers-qwerty-numpad)
		  ((eql layout 'dvorak-numpad)
		   (home-row-numbers-numpad-warning numbers)
		   home-row-numbers-dvorak-numpad)
		  ((stringp layout)
		   (home-row-numbers-string->char-list layout))
		  (t (cl-assert (consp layout)
				nil
				"the LAYOUT argument to
		     home-row-numbers should either be a string
		     or list of characters or one of the symbols
		     specified in the home-row-numbers
		     doc-string")
		     layout)))
	(numbers (cond
		  ((consp numbers) numbers)
		  ((stringp numbers)
		   (home-row-numbers-string->char-list numbers))
		  ((or (eql numbers 'zero)
		       (eql numbers 'zero-first))
		   home-row-numbers-zero)
		  ((or (eql numbers 'programming)
		       (eql numbers 'prog))
		   home-row-numbers-prog)
		  (t home-row-numbers-norm)))
	(ua-prefix
	 (concat
	  (or
	   (ignore-errors
	     (format-kbd-macro
	      (format "%c"
		      (aref
		       (where-is-internal
			#'universal-argument (current-global-map) t)
		       0)))
	     "C-u"))
	  "- ")))
    (cl-assert (= (length letters) (length numbers))
	       nil
	       "the LAYOUT and NUMBERS arguments to home-row-numbers
	    should be the same length")
    `(progn
       (defvar home-row-numbers-already-printed nil
	 "String of what's been printed, for use with
	       decimal functionality")

       (defvar home-row-numbers-leading-zeroes 0
	 "Number of zeroes pressed before another number")

       (defun home-row-numbers-argument (arg)
	 "Translate the home row keys into digits"
	 (interactive "P")
	 (let* ((last-command-event
		 (cl-case last-command-event
		   ,@(cl-loop for k in letters
			      for n in numbers
			      collect `(,k ,n))
		   (t (user-error
		       "home-row-numbers-argument is not configured for %c"
		       last-command-event))))
		(arg-and-key-are-zero
		 (and (eq last-command-event ?0)
		      (or (not (numberp arg))
			  (zerop (prefix-numeric-value arg))))))
	   (when (listp arg)
	     (setq home-row-numbers-already-printed nil
		   home-row-numbers-leading-zeroes 0))
	   (when arg-and-key-are-zero
	     (cl-incf home-row-numbers-leading-zeroes))
	   (digit-argument arg)
	   ,(when message
	      `(let ((message-log-max nil)
		     (prefix-number
		      (prefix-numeric-value prefix-arg))
		     (arg-is-minus-zero
		      (and (eq '- arg)
			   (not (eq last-command-event ?1)))))
		 (message
		  (concat
		   ,ua-prefix
		   home-row-numbers-already-printed
		   (if (< prefix-number 0) "-" "")
		   (apply #'concat
			  (cl-loop for i from
				   (if (and
					arg-and-key-are-zero
					(not arg-is-minus-zero))
				       2 1)
				   to home-row-numbers-leading-zeroes
				   collect "0"))
		   (unless arg-is-minus-zero
		     (number-to-string
		      (abs prefix-number)))))))
	   prefix-arg))

       ,@(when print-key
	   `((defun home-row-numbers-print (arg)
	       "Insert `prefix-arg' into the current buffer."
	       (interactive "*P")
	       (let* ((num-arg (prefix-numeric-value arg))
		      (lead-zeroes
		       (apply #'concat
			      (cl-loop for i from (if (zerop num-arg) 2 1) to
				       home-row-numbers-leading-zeroes
				       collect "0"))))
		 (setq home-row-numbers-already-printed nil
		       home-row-numbers-leading-zeroes 0)
		 (let ((str (concat
			     (if (< num-arg 0) "-" "")
			     lead-zeroes
			     (unless (eq '- arg)
			       (number-to-string (abs num-arg))))))
		   (insert str)
		   str)))

	     ,@(cl-loop for k in (if (consp print-key)
				     print-key
				   (if (stringp print-key)
				       (home-row-numbers-string->char-list
					print-key)
				     (list print-key)))
			collect
			`(define-key universal-argument-map
			   [,k] #'home-row-numbers-print))))

       ,@(when print-and-continue-key
	   (cl-assert print-key nil "The PRINT-AND-CONTINUE-KEY
	   functionality requires at least one PRINT-KEY")
	   `((defun home-row-numbers-continue (arg)
	       "Insert `prefix-arg' into the buffer then continue
	       accepting a `universal-argument'"
	       (interactive "*P")
	       (home-row-numbers-print arg)
	       (insert " ")
	       (universal-argument))

	     ,@(cl-loop for k in (if (consp print-and-continue-key)
				     print-and-continue-key
				   (if (stringp print-and-continue-key)
				       (home-row-numbers-string->char-list
					print-and-continue-key)
				     (list print-and-continue-key)))
			collect
			`(define-key universal-argument-map
			   [,k] #'home-row-numbers-continue))))

       ,@(when decimal-key
	   (cl-assert print-key nil "The DECIMAL-KEY
	   functionality requires at least one PRINT-KEY")
	   `((defun home-row-numbers-decimal (arg)
	       "Insert `prefix-arg' into the current buffer, a
	       decimal, and continue accepting a prefix
	       argument."
	       (interactive "*P")
	       (let ((new-part (home-row-numbers-print arg))
		     (message-log-max nil))
		 (insert ,decimal)
		 (setq home-row-numbers-already-printed
		       (concat home-row-numbers-already-printed
			       new-part
			       ,decimal))
		 ,(when message
		    `(message (concat ,ua-prefix home-row-numbers-already-printed))))
	       (universal-argument)
	       (setq prefix-arg 0))

	     ,@(cl-loop for k in (if (consp decimal-key)
				     decimal-key
				   (if (stringp decimal-key)
				       (home-row-numbers-string->char-list
					decimal-key)
				     (list decimal-key)))
			collect
			`(define-key universal-argument-map
			   [,k] #'home-row-numbers-decimal))))

       ,@(cl-loop for k in letters
		  collect `(define-key universal-argument-map
			     [,k] #'home-row-numbers-argument)))))

(defun home-row-numbers--completing-read (keyword prompt options required)
  (list keyword
	(intern
	 (completing-read prompt options nil required
			  nil nil (first options)))))

;;;###autoload
(cl-defun home-row-numbers (&key (layout 'qwerty)
				 (message t)
				 (print-key ?p)
				 (print-and-continue-key ?\ )
				 (decimal-key ?\.)
				 (decimal ".")
				 (numbers nil)
				 (compile (featurep 'bytecomp)))
  "Setup \\[universal-argument] to accept letters as numbers for
use as either a prefix argument or to print into the current
buffer.

The following keywords are understood:

LAYOUT

One of the symbols: qwerty, dvorak, qwerty-numpad, dvorak-numpad.

The first two use the home row of the respective layouts to input
numbers, while the numpad variants use the keys underneath the
right hand's index, middle, and ring fingers on the home row and
the rows above and below plus the space bar to mimic the numpad.
A string or list of characters can also be provided to be used
instead. LAYOUT keys override PRINT-KEY and DECIMAL-KEY.
Default is qwerty.

MESSAGE

If true the numeric value of `prefix-arg' is printed in the
mini-buffer after each keypress. Default true.

PRINT-KEY

A character to bind `home-row-numbers-print' to. If nil then not
bound. If a string or list of characters all are bound. Default p.

PRINT-AND-CONTINUE-KEY

A character to bind `home-row-numbers-continue' to. Like
PRINT-KEY except prints a space after inserting the numbers and
then continues accepting numbers.

DECIMAL-KEY

A character to bind `home-row-numbers-decimal' to. If nil then
not bound. Requires at least one PRINT-KEY. If a string or list
of characters all are bound. Default period.

DECIMAL

A string to be inserted by `home-row-numbers-decimal'.
Default period.

NUMBERS

One of the symbols: zero-first or programming

The former will move zero to be before one, the latter will
re-order the numbers to be as they are in the programming dvorak
layout. If nil, the default, then order the numbers as they are
on a traditional keyboard layout. Numpad layouts assume this
argument is nil. A string or list of characters can also be
provided to be used instead.

COMPILE

If t then byte-compile the functions generated by
home-row-numbers. Unnecessary if the call to home-row-numbers is
itself byte-compiled. Defaults to t if the byte-compiler is
already loaded."
  (interactive
   (progn
     (home-row-numbers-disable)
     (append
      (home-row-numbers--completing-read
       :layout "Layout: "
       '("qwerty" "dvorak" "qwerty-numpad" "dvorak-numpad")
       'confirm)
      (home-row-numbers--completing-read
       :message "Message: "
       '("t" "nil")
       t)
      (list :print-key
	    (home-row-numbers-string->char-list
	     (completing-read "Print-key(s): "
			      '("p")
			      nil nil nil nil
			      "p")))
      (list :print-and-continue-key
	    (home-row-numbers-string->char-list
	     (completing-read "Print-and-continue-key(s): "
			      '(" ")
			      nil nil nil nil
			      " ")))
      (list :decimal-key
	    (home-row-numbers-string->char-list
	     (completing-read "Decimal-key(s): "
			      '("." ",")
			      nil nil nil nil
			      ".")))
      (list :decimal
	    (completing-read "Decimal: "
			     '("." ",")
			     nil nil nil nil
			     "."))
      (home-row-numbers--completing-read
       :numbers "Numbers: "
       '("normal" "zero-first" "programmer")
       'confirm))))
  (eval `(home-row-numbers-helper
	  :layout ,layout
	  :message ,message
	  :print-key ,print-key
	  :print-and-continue-key ,print-and-continue-key
	  :decimal-key ,decimal-key
	  :decimal ,decimal
	  :numbers ,(unless (eql numbers 'normal) numbers))
	t)
  (when (and compile
             (or (not (fboundp 'subr-native-elisp-p))
                 (not (subr-native-elisp-p (symbol-function #'home-row-numbers-argument)))))
    (byte-compile #'home-row-numbers-argument))
    (when (and print-key
               (or (not (fboundp 'subr-native-elisp-p))
                   (not (subr-native-elisp-p (symbol-function #'home-row-numbers-print)))))
        (byte-compile #'home-row-numbers-print))
      (when (and print-and-continue-key
                 (or (not (fboundp 'subr-native-elisp-p))
                     (not (subr-native-elisp-p (symbol-function #'home-row-numbers-continue)))))
	(byte-compile #'home-row-numbers-continue))
      (when (and decimal-key
                 (or (not (fboundp 'subr-native-elisp-p))
                     (not (subr-native-elisp-p (symbol-function #'home-row-numbers-decimal)))))
	(byte-compile #'home-row-numbers-decimal)))

(cl-define-compiler-macro home-row-numbers (&whole form &rest args)
  (if (cl-every
       (lambda (x)
	 (or (keywordp x)
	     (eq x t)
	     (eq x nil)
	     (integerp x)
	     (stringp x)
	     (and (consp x)
		  (eq (first x)
		      'quote))))
       args)
      `(home-row-numbers-helper
	,@(cl-loop for arg in args collect
		   (if (consp arg)
		       (second arg)
		     arg)))
    form))

;;;###autoload
(defun home-row-numbers-disable ()
  "Disable home-row-numbers"
  (interactive)
  (substitute-key-definition 'home-row-numbers-argument
			     nil
			     universal-argument-map)
  (substitute-key-definition 'home-row-numbers-print
			     nil
			     universal-argument-map)
  (substitute-key-definition 'home-row-numbers-continue
			     nil
			     universal-argument-map)
  (substitute-key-definition 'home-row-numbers-decimal
			     nil
			     universal-argument-map))

(provide 'home-row-numbers)
