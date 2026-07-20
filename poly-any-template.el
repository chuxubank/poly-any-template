;;; poly-any-template.el --- Shared support for template polymodes -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka

;; Author: Misaka <chuxubank@qq.com>
;; Maintainer: Misaka <chuxubank@qq.com>
;; Version: 0.1.6
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

(defvar-local poly-any-template--active nil
  "Non-nil in buffers activated by a poly-any template mode.")

(defvar poly-any-template--inferring-host-mode nil
  "Non-nil while selecting the host mode for a template buffer.")

(defun poly-any-template--indent-bars-filter-blank-lines
    (function beg end &rest args)
  "Call FUNCTION for real blank lines between BEG and END with ARGS.
Polymode hides inner spans while fontifying the host, which makes template
action lines look blank to `indent-bars'."
  (if (not poly-any-template--active)
      (apply function beg end args)
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
                (forward-line 1)))))))))

(defun poly-any-template--install-indent-bars-filter ()
  "Install blank-line filtering for optional `indent-bars' integration."
  (unless (advice-member-p
           #'poly-any-template--indent-bars-filter-blank-lines
           'indent-bars--display-blank-lines)
    (advice-add 'indent-bars--display-blank-lines :around
                #'poly-any-template--indent-bars-filter-blank-lines)))

(with-eval-after-load 'indent-bars
  (poly-any-template--install-indent-bars-filter))

(defun poly-any-template--extra-file-name-p (filename rules)
  "Return non-nil when FILENAME matches an entry in RULES.
Each rule may be a regexp or a function called with FILENAME."
  (and (not poly-any-template--inferring-host-mode)
       filename
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

(defun poly-any-template-host-mode-for-file (filename)
  "Return the major mode selected for FILENAME."
  (when filename
    (ignore-errors
      (let ((poly-any-template--inferring-host-mode t))
        (with-temp-buffer
          (set-visited-file-name filename t t)
          (set-auto-mode)
          (unless (eq major-mode 'fundamental-mode)
            major-mode))))))

(defun poly-any-template--activate
    (dialect innermode lighter-variable remove-template-suffix)
  "Activate a polymode for DIALECT using INNERMODE and LIGHTER-VARIABLE.
REMOVE-TEMPLATE-SUFFIX is passed to `poly-any-template--host-filename'."
  (let* ((base-filename
          (poly-any-template--host-filename
           buffer-file-name remove-template-suffix))
         (host-major-mode
          (or (poly-any-template-host-mode-for-file base-filename)
              'text-mode))
         (host-mode-symbol
          (intern (format "poly-%s-%s-hostmode" host-major-mode dialect)))
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
    (setq-local poly-any-template--active t)
    (when (and (bound-and-true-p indent-bars-mode)
               (fboundp 'jit-lock-refontify))
      (funcall 'jit-lock-refontify))
    (run-hooks 'poly-any-template-after-activate-hook)))

(provide 'poly-any-template)
;;; poly-any-template.el ends here
