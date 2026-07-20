;;; poly-any-jinja2.el --- Polymode for Jinja2 templates -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka
;; Version: 0.1.10
;; Package-Requires: ((emacs "29.1") (poly-any-template "0.1.8") (jinja2-ts-mode "0.1.1"))
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

(defcustom poly-any-jinja2-extra-file-name-rules nil
  "Additional file-name rules that select `poly-any-jinja2-mode'.
These rules are intended for templates identified by their path or naming
convention rather than a Jinja suffix.  Their final extension is preserved
when inferring the host mode.  Each rule may be a regexp or a function that
accepts the file name and returns non-nil when it matches."
  :type '(repeat (choice regexp function))
  :group 'poly-any-template)

(defconst poly-any-jinja2--template-suffix-regexp
  "\\.\\(?:j2\\|jinja\\|jinja2\\)\\'"
  "Regexp matching standard Jinja2 template suffixes.")

;;;###autoload
(defun poly-any-jinja2--extra-file-name-p ()
  "Return non-nil when the current file matches an extra Jinja2 rule."
  (poly-any-template--extra-file-name-p
   buffer-file-name poly-any-jinja2-extra-file-name-rules))

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
   'poly-any-jinja2-lighter
   (and buffer-file-name
        (string-match-p poly-any-jinja2--template-suffix-regexp
                        buffer-file-name))
   #'jinja2-ts-mode))

;;;###autoload
(add-to-list 'magic-mode-alist
             '(poly-any-jinja2--extra-file-name-p . poly-any-jinja2-mode))

;;;###autoload
(add-to-list 'auto-mode-alist
             '("\\.\\(?:j2\\|jinja\\|jinja2\\)\\'" . poly-any-jinja2-mode))

(provide 'poly-any-jinja2)
;;; poly-any-jinja2.el ends here
