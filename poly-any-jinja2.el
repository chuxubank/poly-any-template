;;; poly-any-jinja2.el --- Polymode for Jinja2 templates -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka
;; Version: 0.1.5
;; Package-Requires: ((emacs "29.1") (polymode "0.2") (jinja2-mode "20220117.807"))
;; Keywords: languages, polymode, templates, jinja2
;; URL: https://github.com/chuxubank/poly-any-template

;;; Commentary:

;; Jinja2-specific implementation for the `poly-any-template' package.

;;; Code:

(require 'poly-any-template)
(require 'jinja2-mode)

(defcustom poly-any-jinja2-lighter " J2"
  "Mode-line lighter used by Jinja2 polymodes.
The value may be any valid mode-line construct, or nil to hide the lighter."
  :type 'sexp
  :group 'poly-any-template)

(define-innermode poly-any-template-jinja2-innermode
  :mode #'jinja2-mode
  :head-matcher "{[%{#][+-]?"
  :tail-matcher "[+-]?[%}#]}"
  :head-mode 'body
  :tail-mode 'body
  :head-adjust-face nil)

;;;###autoload
(defun poly-any-jinja2-mode ()
  "Edit Jinja2 templates using the mode inferred from the host filename."
  (interactive)
  (poly-any-template--activate
   "jinja2" 'poly-any-template-jinja2-innermode
   'poly-any-jinja2-lighter))

;;;###autoload
(add-to-list 'auto-mode-alist
             '("\\.\\(?:j2\\|jinja2\\)\\'" . poly-any-jinja2-mode))

(provide 'poly-any-jinja2)
;;; poly-any-jinja2.el ends here
