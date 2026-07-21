;;; poly-any-jinja2.el --- Polymode for Jinja2 templates -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka
;; Version: 0.1.15
;; Package-Requires: ((emacs "29.1") (poly-any-template "0.1.14") (jinja2-ts-mode "0.1.1"))
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

(defcustom poly-any-jinja2-hostless-mode #'jinja2-ts-mode
  "Mode used when no Jinja2 host mode can be inferred.
Set this to nil to use `text-mode' as a polymode host instead."
  :type '(choice (const :tag "Text polymode host" nil) function)
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
  (pcase (char-after (1+ (point)))
    (?{ (poly-any-template--lexical-tail-matcher "}}" '(?\" ?\')))
    (?% (poly-any-template--lexical-tail-matcher "%}" '(?\" ?\')))
    (?# (poly-any-template--lexical-tail-matcher "#}" nil))))

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
   poly-any-jinja2-hostless-mode))

;;;###autoload
(add-to-list 'magic-mode-alist
             '(poly-any-jinja2--extra-file-name-p . poly-any-jinja2-mode))

;;;###autoload
(let* ((entry '("\\.\\(?:j2\\|jinja\\|jinja2\\)\\'"
                . poly-any-jinja2-mode))
       (register
        (lambda ()
          (setq auto-mode-alist
                (cons entry (delete entry auto-mode-alist))))))
  (funcall register)
  (eval-after-load 'jinja2-ts-mode-autoloads register))

(provide 'poly-any-jinja2)
;;; poly-any-jinja2.el ends here
