;;; poly-any-template.el --- Shared support for template polymodes -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka

;; Author: Misaka <chuxubank@qq.com>
;; Maintainer: Misaka <chuxubank@qq.com>
;; Version: 0.1.4
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
value is the template filename without its final extension."
  :type '(repeat function)
  :group 'poly-any-template)

(defcustom poly-any-template-indent-bars-display-on-blank-lines nil
  "How `indent-bars' should display blank lines in template polymodes.
The default disables blank-line bars because Polymode presents inner spans as
blank text while fontifying the host.  Enabling them would make `indent-bars'
invent trailing guides on lines containing template actions."
  :type '(choice
          (const :tag "Disabled" nil)
          (const :tag "Deepest adjacent" t)
          (const :tag "Least deep adjacent" least))
  :group 'poly-any-template)

(defvar poly-any-template-after-activate-hook nil
  "Hook run after a poly-any template mode has been activated.")

(defun poly-any-template--configure-indent-bars ()
  "Configure optional `indent-bars' support for the current polymode buffer."
  (let ((reset-p
         (and (bound-and-true-p indent-bars-mode)
              (not (equal (symbol-value 'indent-bars-display-on-blank-lines)
                          poly-any-template-indent-bars-display-on-blank-lines)))))
    (set (make-local-variable 'indent-bars-display-on-blank-lines)
         poly-any-template-indent-bars-display-on-blank-lines)
    (when (and reset-p (fboundp 'indent-bars-reset))
      (funcall 'indent-bars-reset))))

(defun poly-any-template--host-filename (filename)
  "Return the host filename inferred from template FILENAME."
  (let ((host-filename (when filename
                         (file-name-sans-extension filename))))
    (dolist (function poly-any-template-host-filename-functions
                      host-filename)
      (setq host-filename (funcall function host-filename)))))

(defun poly-any-template--get-major-mode-for-file (filename)
  "Return the major mode selected for FILENAME."
  (when filename
    (ignore-errors
      (with-temp-buffer
        (set-visited-file-name filename t t)
        (set-auto-mode)
        (unless (eq major-mode 'fundamental-mode)
          major-mode)))))

(defun poly-any-template--activate (dialect innermode lighter-variable)
  "Activate a polymode for DIALECT using INNERMODE and LIGHTER-VARIABLE."
  (let* ((base-filename (poly-any-template--host-filename buffer-file-name))
         (host-major-mode
          (or (poly-any-template--get-major-mode-for-file base-filename)
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
    (poly-any-template--configure-indent-bars)
    (run-hooks 'poly-any-template-after-activate-hook)))

(provide 'poly-any-template)
;;; poly-any-template.el ends here
