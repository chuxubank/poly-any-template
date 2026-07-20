;;; poly-any-template.el --- Shared support for template polymodes -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka

;; Author: Misaka <chuxubank@qq.com>
;; Maintainer: Misaka <chuxubank@qq.com>
;; Version: 0.1.11
;; Package-Requires: ((emacs "29.1") (polymode "0.2"))
;; Keywords: languages, polymode, templates
;; URL: https://github.com/chuxubank/poly-any-template

;;; Commentary:

;; Shared support for the independently installable
;; `poly-any-jinja2.el' and `poly-any-go-template.el' packages.

;;; Code:

(require 'polymode)
(require 'subr-x)

(defgroup poly-any-template nil
  "Shared support for template polymodes."
  :group 'polymode)

(defcustom poly-any-template-host-filename-functions nil
  "Functions that transform a template's inferred host filename.
Each function receives the result of the previous function.  The initial
value is the template filename after removing a recognized template suffix,
when present."
  :type '(repeat function)
  :group 'poly-any-template)

(defvar poly-any-template-after-activate-hook nil
  "Hook run after a poly-any template mode has been activated.")

(defvar-local poly-any-template--indent-bars-blank-line-function nil
  "Original indent-bars blank-line display function for this buffer.")

(defun poly-any-template--indent-bars-filter-blank-lines
    (function beg end &rest args)
  "Call FUNCTION for real blank lines between BEG and END with ARGS.
Polymode hides inner spans while fontifying the host, which makes template
action lines look blank to `indent-bars'."
  (save-excursion
    (save-restriction
      (widen)
      (save-match-data
        (goto-char beg)
        (let ((limit (min end (point-max))))
          (while (< (point) limit)
            (if (looking-at "[ \t]*\n")
                (let ((run-beg (point)))
                  (while (and (< (point) limit)
                              (looking-at "[ \t]*\n"))
                    (forward-line 1))
                  (let ((run-end (point)))
                    (apply function run-beg run-end args)
                    (goto-char run-end)))
              (forward-line 1))))))))

(defun poly-any-template--indent-bars-display-blank-lines
    (beg end &rest args)
  "Display indent bars on real blank lines between BEG and END with ARGS."
  (apply #'poly-any-template--indent-bars-filter-blank-lines
         poly-any-template--indent-bars-blank-line-function beg end args))

(defun poly-any-template--configure-indent-bars ()
  "Configure optional indent-bars integration in the current buffer."
  (let ((current
         (and (boundp 'indent-bars--display-blank-lines-function)
              (symbol-value 'indent-bars--display-blank-lines-function))))
    (unless (eq current
                #'poly-any-template--indent-bars-display-blank-lines)
      (setq-local poly-any-template--indent-bars-blank-line-function
                  (or current 'indent-bars--display-blank-lines)))
    (set (make-local-variable
          'indent-bars--display-blank-lines-function)
         #'poly-any-template--indent-bars-display-blank-lines)))

(defun poly-any-template--extra-file-name-p (filename rules)
  "Return non-nil when FILENAME matches an entry in RULES.
Each rule may be a regexp or a function called with FILENAME."
  (and filename
       (catch 'matched
         (dolist (rule rules)
           (when (if (functionp rule)
                     (funcall rule filename)
                   (string-match-p rule filename))
             (throw 'matched t))))))

(defun poly-any-template--host-filename (filename remove-template-suffix)
  "Return the host filename inferred from template FILENAME.
Remove the final extension when REMOVE-TEMPLATE-SUFFIX is non-nil, then
apply `poly-any-template-host-filename-functions'."
  (let ((host-filename
         (cond ((not filename) nil)
               (remove-template-suffix
                (file-name-sans-extension filename))
               (t filename))))
    (dolist (function poly-any-template-host-filename-functions
                      host-filename)
      (setq host-filename (funcall function host-filename)))))

(defun poly-any-template--lexical-tail-matcher
    (delimiter quote-characters &optional raw-quote-characters block-comment)
  "Find lexical DELIMITER and return a zero-width match.
QUOTE-CHARACTERS is a list of characters that open and close strings.
Backslash escapes the following character inside those strings, except when
the quote character is also present in RAW-QUOTE-CHARACTERS.  BLOCK-COMMENT,
when non-nil, is a cons of its opening and closing strings."
  (let ((delimiter-regexp (regexp-quote delimiter))
        (comment-start-regexp
         (and block-comment (regexp-quote (car block-comment))))
        (comment-end-regexp
         (and block-comment (regexp-quote (cdr block-comment))))
        quote
        in-comment
        found)
    (while (and (not found) (< (point) (point-max)))
      (let ((character (char-after)))
        (cond
         ((and in-comment (looking-at-p comment-end-regexp))
          (forward-char (length (cdr block-comment)))
          (setq in-comment nil))
         (in-comment
          (forward-char 1))
         ((and (not quote) (looking-at-p delimiter-regexp))
          (forward-char (length delimiter))
          (setq found (point)))
         ((and (not quote) comment-start-regexp
               (looking-at-p comment-start-regexp))
          (forward-char (length (car block-comment)))
          (setq in-comment t))
         ((not quote)
          (when (memq character quote-characters)
            (setq quote character))
          (forward-char 1))
         ((and (eq character ?\\)
               (not (memq quote raw-quote-characters)))
          (forward-char (min 2 (- (point-max) (point)))))
         ((eq character quote)
          (setq quote nil)
          (forward-char 1))
         (t
          (forward-char 1)))))
    (when found
      (cons found found))))

(defun poly-any-template--auto-mode-match (filename case-insensitive-p)
  "Return the `auto-mode-alist' value matching FILENAME.
CASE-INSENSITIVE-P describes the filesystem of the original template file."
  (if case-insensitive-p
      (let ((case-fold-search t))
        (assoc-default filename auto-mode-alist #'string-match))
    (or (let ((case-fold-search nil))
          (assoc-default filename auto-mode-alist #'string-match))
        (and auto-mode-case-fold
             (let ((case-fold-search t))
               (assoc-default filename auto-mode-alist #'string-match))))))

(defun poly-any-template--auto-mode-for-file (filename)
  "Return the mode function selected for FILENAME without calling it."
  (let ((name (file-name-sans-versions filename))
        (remote-id (file-remote-p filename))
        (case-insensitive-p (file-name-case-insensitive-p filename))
        mode)
    (when (and (stringp remote-id)
               (string-match (regexp-quote remote-id) name))
      (setq name (substring name (match-end 0))))
    (while name
      (setq mode (poly-any-template--auto-mode-match
                  name case-insensitive-p))
      (if (and (not (functionp mode))
               (consp mode)
               (cadr mode))
          (setq mode (car mode)
                name (substring name 0 (match-beginning 0)))
        (setq name nil)))
    mode))

(defun poly-any-template--remap-mode (mode)
  "Return MODE after major-mode remapping when it remains a named function."
  (let ((remapped
         (if (fboundp 'major-mode-remap)
             (funcall 'major-mode-remap mode)
           (or (cdr (assq mode major-mode-remap-alist)) mode))))
    (when (and (symbolp remapped)
               (functionp remapped)
               (not (eq remapped 'fundamental-mode)))
      remapped)))

;;;###autoload
(defun poly-any-template-host-mode-for-file (filename)
  "Return the named mode function selected for FILENAME.
Only `auto-mode-alist' is consulted, and the selected function is not run."
  (when filename
    (ignore-errors
      (when-let ((mode (poly-any-template--auto-mode-for-file filename)))
        (poly-any-template--remap-mode mode)))))

(defun poly-any-template--activate
    (dialect innermode lighter-variable remove-template-suffix
             &optional hostless-mode)
  "Activate a polymode for DIALECT using INNERMODE and LIGHTER-VARIABLE.
REMOVE-TEMPLATE-SUFFIX is passed to `poly-any-template--host-filename'.
When no host mode is inferred, call HOSTLESS-MODE if it is non-nil; otherwise
use `text-mode' as the polymode host."
  (let* ((base-filename
          (poly-any-template--host-filename
           buffer-file-name remove-template-suffix))
         (host-major-mode
          (poly-any-template-host-mode-for-file base-filename)))
    (if (and (not host-major-mode) hostless-mode)
        (funcall hostless-mode)
      (let* ((host-major-mode (or host-major-mode 'text-mode))
             (host-mode-symbol
              (intern (format "poly-%s-%s-hostmode"
                              host-major-mode dialect)))
             (polymode-symbol
              (intern (format "poly-%s-%s-mode"
                              (string-remove-suffix
                               "-mode" (symbol-name host-major-mode))
                              dialect))))
        (unless (fboundp host-mode-symbol)
          (eval `(define-hostmode ,host-mode-symbol
                   :mode ',host-major-mode
                   :protect-font-lock t)
                t))
        (unless (fboundp polymode-symbol)
          (eval `(define-polymode ,polymode-symbol
                   :hostmode ',host-mode-symbol
                   :innermodes '(,innermode)
                   :lighter ',lighter-variable) t))
        (funcall polymode-symbol)
        (poly-any-template--configure-indent-bars)
        (when (and (bound-and-true-p indent-bars-mode)
                   (fboundp 'jit-lock-refontify))
          (funcall 'jit-lock-refontify))
        (run-hooks 'poly-any-template-after-activate-hook)))))

(provide 'poly-any-template)
;;; poly-any-template.el ends here
