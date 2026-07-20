;;; poly-treesit-fold-test.el --- Tests for poly-treesit-fold -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'poly-any-go-template)
(require 'poly-any-jinja2)
(require 'poly-treesit-fold)
(require 'toml-ts-mode nil t)

(ert-deftest poly-treesit-fold-mode-manages-advice ()
  (unwind-protect
      (progn
        (poly-treesit-fold-mode 1)
        (dolist (function poly-treesit-fold--advised-functions)
          (should (advice-member-p #'poly-treesit-fold--with-parser
                                   function))))
    (poly-treesit-fold-mode -1))
  (dolist (function poly-treesit-fold--advised-functions)
    (should-not (advice-member-p #'poly-treesit-fold--with-parser function))))

(ert-deftest poly-treesit-fold-uses-only-the-primary-parser ()
  (let ((treesit-primary-parser 'primary))
    (cl-letf (((symbol-function 'treesit-parser-list)
               (lambda () '(secondary primary)))
              ((symbol-function 'treesit-parser-root-node)
               (lambda (parser)
                 (should (eq parser 'primary))
                 'root)))
      (should (eq (poly-treesit-fold--root-node) 'root)))))

(ert-deftest poly-treesit-fold-folds-go-template-inner-span ()
  (skip-unless (treesit-ready-p 'gotmpl))
  (let ((poly-any-template-host-filename-functions
         (list (lambda (filename)
                 (replace-regexp-in-string
                  "/dot_\\([^/]+\\)\\'" "/.\\1" filename))))
        folded)
    (unwind-protect
        (progn
          (poly-treesit-fold-mode 1)
          (with-temp-buffer
            (setq buffer-file-name "/tmp/dot_zprofile.tmpl")
            (insert "export A=1\n"
                    "{{ if .enabled }}\n"
                    "export B=2\n"
                    "{{ end }}\n")
            (poly-any-go-template-mode)
            (should (eq major-mode 'sh-mode))
            (should (eq sh-shell 'zsh))
            (should polymode-mode)
            (should-not (poly-treesit-fold--root-node))
            (pm-map-over-spans
             (lambda (span)
               (when (and (eq (car span) 'body) (not folded))
                 (when-let* ((root (poly-treesit-fold--root-node))
                             (capture
                              (car (treesit-query-capture
                                    root '((if_action) @node))))
                             (overlay (treesit-fold-close (cdr capture))))
                   (should (eq (treesit-node-language root) 'gotmpl))
                   (should (eq (overlay-get overlay 'creator) 'treesit-fold))
                   (setq folded t)))))
            (should folded)))
      (poly-treesit-fold-mode -1))))

(ert-deftest poly-treesit-fold-folds-jinja2-inner-span ()
  (skip-unless (treesit-ready-p 'jinja))
  (let (folded)
    (unwind-protect
        (progn
          (poly-treesit-fold-mode 1)
          (with-temp-buffer
            (setq buffer-file-name "/tmp/config.text.j2")
            (insert "{% if enabled %}\n"
                    "value\n"
                    "{% endif %}\n")
            (poly-any-jinja2-mode)
            (pm-map-over-spans
             (lambda (span)
               (when (and (eq (car span) 'body) (not folded))
                 (when-let* ((root (poly-treesit-fold--root-node))
                             (capture
                              (car (treesit-query-capture
                                    root '((if_block) @node))))
                             (overlay (treesit-fold-close (cdr capture))))
                   (should (eq (treesit-node-language root) 'jinja))
                   (should (eq (overlay-get overlay 'creator) 'treesit-fold))
                   (setq folded t)))))
            (should folded)))
      (poly-treesit-fold-mode -1))))

(ert-deftest poly-treesit-fold-keeps-toml-host-parser ()
  (skip-unless (and (fboundp 'toml-ts-mode)
                    (treesit-ready-p 'toml)
                    (treesit-ready-p 'gotmpl)))
  (let ((auto-mode-alist '(("\\.toml\\'" . toml-ts-mode))))
    (unwind-protect
        (progn
          (poly-treesit-fold-mode 1)
          (with-temp-buffer
            (setq buffer-file-name "/tmp/common.toml.tmpl")
            (insert "enabled = true\n"
                    "{{ if .enabled }}\n"
                    "name = \"example\"\n"
                    "{{ end }}\n")
            (poly-any-go-template-mode)
            (let ((root (poly-treesit-fold--root-node)))
              (should (eq major-mode 'toml-ts-mode))
              (should (eq (treesit-node-language root) 'toml))
              (should-not
               (condition-case nil
                   (progn (treesit-fold-indicators-refresh) nil)
                 (error t))))))
      (poly-treesit-fold-mode -1))))

(provide 'poly-treesit-fold-test)
;;; poly-treesit-fold-test.el ends here
