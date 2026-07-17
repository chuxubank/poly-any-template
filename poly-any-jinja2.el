;;; poly-any-jinja2.el --- Polymode for Jinja2 templates -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka

;;; Commentary:

;; Jinja2-specific implementation for the `poly-any-template' package.

;;; Code:

(require 'poly-any-template)
(require 'poly-jinja2)

;;;###autoload
(defun poly-any-jinja2-mode ()
  "Edit Jinja2 templates using the mode inferred from the host filename."
  (interactive)
  (poly-any-template--activate "jinja2" 'poly-jinja2-innermode " J2"))

(provide 'poly-any-jinja2)
;;; poly-any-jinja2.el ends here
