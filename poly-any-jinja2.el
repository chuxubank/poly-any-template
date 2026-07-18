;;; poly-any-jinja2.el --- Polymode for Jinja2 templates -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka
;; Version: 0.1.2
;; Package-Requires: ((emacs "29.1") (polymode "0.2") (jinja2-mode "20220117.807"))
;; Keywords: languages, polymode, templates, jinja2
;; URL: https://github.com/chuxubank/poly-any-template

;;; Commentary:

;; Jinja2-specific implementation for the `poly-any-template' package.

;;; Code:

(require 'poly-any-template)
(require 'jinja2-mode)

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
   "jinja2" 'poly-any-template-jinja2-innermode " J2"))

;;;###autoload
(defun poly-any-ansible-mode ()
  "Edit Ansible YAML containing embedded Jinja2 templates."
  (interactive)
  (let ((buffer-file-name
         (concat (or buffer-file-name "ansible.yaml") ".j2")))
    (poly-any-jinja2-mode))
  (when (fboundp 'ansible-mode)
    (ansible-mode 1))
  (when (fboundp 'ansible-doc-mode)
    (ansible-doc-mode 1)))

;;;###autoload
(add-to-list 'auto-mode-alist
             '("\\.\\(?:j2\\|jinja2\\)\\'" . poly-any-jinja2-mode))

;;;###autoload
(add-to-list 'auto-mode-alist
             '("/ansible/.*\\.ya?ml\\'" . poly-any-ansible-mode))

;;;###autoload
(add-to-list 'auto-mode-alist
             '("/\\(?:group\\|host\\)_vars/" . poly-any-ansible-mode))

(provide 'poly-any-jinja2)
;;; poly-any-jinja2.el ends here
