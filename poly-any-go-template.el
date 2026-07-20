;;; poly-any-go-template.el --- Polymode for Go templates -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka
;; Version: 0.1.3
;; Package-Requires: ((emacs "29.1") (polymode "0.2") (go-template-ts-mode "0.1.0"))
;; Keywords: languages, polymode, templates, go
;; URL: https://github.com/chuxubank/poly-any-template

;;; Commentary:

;; Go-template-specific implementation for the `poly-any-template' package.

;;; Code:

(require 'poly-any-template)
(require 'go-template-ts-mode)

(defcustom poly-any-go-template-lighter " GoTpl"
  "Mode-line lighter used by Go Template polymodes.
The value may be any valid mode-line construct, or nil to hide the lighter."
  :type 'sexp
  :group 'poly-any-template)

(defun poly-any-template--go-head-matcher (direction)
  "Find a Go template action start in DIRECTION.
Return a zero-width match so the inner span includes the opening delimiter."
  (let ((found (if (< direction 0)
                   (re-search-backward "{{-?" nil t)
                 (re-search-forward "{{-?" nil t))))
    (when found
      (cons (match-beginning 0) (match-beginning 0)))))

(defun poly-any-template--go-tail-matcher (_direction)
  "Find the current Go template action end and return a zero-width match."
  (when (re-search-forward "-?}}" nil t)
    (cons (match-end 0) (match-end 0))))

(define-innermode poly-any-template-go-innermode
  :mode #'go-template-ts-mode
  :head-matcher #'poly-any-template--go-head-matcher
  :tail-matcher #'poly-any-template--go-tail-matcher
  :head-adjust-face nil)

;;;###autoload
(defun poly-any-go-template-mode ()
  "Edit Go templates using the mode inferred from the host filename."
  (interactive)
  (poly-any-template--activate
   "go-template" 'poly-any-template-go-innermode
   'poly-any-go-template-lighter))

;;;###autoload
(add-to-list 'auto-mode-alist
             '("\\.[^./]+\\.\\(?:gotmpl\\|tmpl\\)\\'"
               . poly-any-go-template-mode))

(provide 'poly-any-go-template)
;;; poly-any-go-template.el ends here
