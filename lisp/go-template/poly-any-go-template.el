;;; poly-any-go-template.el --- Polymode for Go templates -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka
;; Version: 0.1.13
;; Package-Requires: ((emacs "29.1") (poly-any-template "0.1.12") (go-template-ts-mode "0.1.7"))
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

(defcustom poly-any-go-template-extra-file-name-rules nil
  "Additional file-name rules that select `poly-any-go-template-mode'.
These rules are intended for templates identified by their path or naming
convention rather than a `.tmpl' or `.gotmpl' suffix.  Their final extension
is preserved when inferring the host mode.  Each rule may be a regexp or a
function that accepts the file name and returns non-nil when it matches."
  :type '(repeat (choice regexp function))
  :group 'poly-any-template)

(defconst poly-any-go-template--template-suffix-regexp
  "\\.\\(?:gotmpl\\|tmpl\\)\\'"
  "Regexp matching standard Go Template suffixes.")

;;;###autoload
(defun poly-any-go-template--extra-file-name-p ()
  "Return non-nil when the current file matches an extra Go Template rule."
  (poly-any-template--extra-file-name-p
   buffer-file-name poly-any-go-template-extra-file-name-rules))

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
  (poly-any-template--lexical-tail-matcher
   "}}" '(?\" ?`) '(?`) '("/*" . "*/")))

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
   'poly-any-go-template-lighter
   (and buffer-file-name
        (string-match-p poly-any-go-template--template-suffix-regexp
                        buffer-file-name))
   #'go-template-ts-mode))

;;;###autoload
(add-to-list 'magic-mode-alist
             '(poly-any-go-template--extra-file-name-p
               . poly-any-go-template-mode))

;;;###autoload
(let* ((entry '("\\.[^./]+\\.\\(?:gotmpl\\|tmpl\\)\\'"
                . poly-any-go-template-mode))
       (register
        (lambda ()
          (setq auto-mode-alist
                (cons entry (delete entry auto-mode-alist))))))
  (funcall register)
  (eval-after-load 'go-template-ts-mode-autoloads register))

(provide 'poly-any-go-template)
;;; poly-any-go-template.el ends here
