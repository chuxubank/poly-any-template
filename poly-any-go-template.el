;;; poly-any-go-template.el --- Polymode for Go templates -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka

;;; Commentary:

;; Go-template-specific implementation for the `poly-any-template' package.

;;; Code:

(require 'poly-any-template)
(require 'go-template-ts-mode)

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
   "go-template" 'poly-any-template-go-innermode " GoTpl"))

(provide 'poly-any-go-template)
;;; poly-any-go-template.el ends here
