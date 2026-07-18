;;; poly-any-template.el --- Shared support for template polymodes -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka

;; Author: Misaka <chuxubank@qq.com>
;; Maintainer: Misaka <chuxubank@qq.com>
;; Version: 0.1.2
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

(defvar poly-any-template-after-activate-hook nil
  "Hook run after a poly-any template mode has been activated.")

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

(defun poly-any-template--activate (dialect innermode lighter)
  "Activate a polymode for DIALECT using INNERMODE and LIGHTER."
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
               :lighter ,lighter) t))
    (funcall polymode-symbol)
    (run-hooks 'poly-any-template-after-activate-hook)))

(provide 'poly-any-template)
;;; poly-any-template.el ends here
