;;; poly-any-jinja2.el --- Polymode for Jinja2 templates -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka
;; Version: 0.1.6
;; Package-Requires: ((emacs "29.1") (polymode "0.2") (jinja2-ts-mode "0.1.0"))
;; Keywords: languages, polymode, templates, jinja2
;; URL: https://github.com/chuxubank/poly-any-template

;;; Commentary:

;; Jinja2-specific implementation for the `poly-any-template' package.

;;; Code:

(require 'poly-any-template)
(require 'jinja2-ts-mode)

(defcustom poly-any-jinja2-lighter " J2"
  "Mode-line lighter used by Jinja2 polymodes.
The value may be any valid mode-line construct, or nil to hide the lighter."
  :type 'sexp
  :group 'poly-any-template)

(defun poly-any-template--jinja2-head-matcher (direction)
  "Find a Jinja tag start in DIRECTION.
Return a zero-width match so the inner span includes the opening delimiter."
  (let ((found (if (< direction 0)
                   (re-search-backward "{[{%#][+-]?" nil t)
                 (re-search-forward "{[{%#][+-]?" nil t))))
    (when found
      (cons (match-beginning 0) (match-beginning 0)))))

(defun poly-any-template--jinja2-tail-matcher (_direction)
  "Find the current Jinja tag end and return a zero-width match."
  (when (re-search-forward "[+-]?\\(?:}}\\|%}\\|#}\\)" nil t)
    (cons (match-end 0) (match-end 0))))

(define-innermode poly-any-template-jinja2-innermode
  :mode #'jinja2-ts-mode
  :head-matcher #'poly-any-template--jinja2-head-matcher
  :tail-matcher #'poly-any-template--jinja2-tail-matcher
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
             '("\\.\\(?:j2\\|jinja\\|jinja2\\)\\'" . poly-any-jinja2-mode))

(provide 'poly-any-jinja2)
;;; poly-any-jinja2.el ends here
