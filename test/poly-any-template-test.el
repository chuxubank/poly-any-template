;;; poly-any-template-test.el --- Tests for poly-any-template -*- lexical-binding: t; no-byte-compile: t; -*-

;;; Code:

(require 'ert)
(require 'poly-any-template)
(require 'poly-any-go-template)
(require 'poly-any-jinja2)

(ert-deftest poly-any-template-detects-interpreter-mode ()
  (let ((interpreter-mode-alist '(("zsh" . sh-mode)))
        (major-mode-remap-alist nil)
        (major-mode-remap-defaults nil))
    (with-temp-buffer
      (insert "#!/bin/zsh\n")
      (should (eq (poly-any-template--interpreter-mode) 'sh-mode)))))

(ert-deftest poly-any-template-prefers-interpreter-over-host-filename ()
  (let ((auto-mode-alist '(("\\.py\\'" . python-mode)))
        (interpreter-mode-alist '(("zsh" . sh-mode))))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/script.py.tmpl")
      (insert "#!/bin/zsh\n{{ .value }}\n")
      (poly-any-go-template-mode)
      (should (eq major-mode 'sh-mode))
      (should polymode-mode))))

(ert-deftest poly-any-go-template-detects-extensionless-shell-host ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/executable_phoneshot.tmpl")
    (insert "#!/usr/bin/env zsh\n{{ .value }}\n")
    (poly-any-go-template-mode)
    (should (eq major-mode 'sh-mode))
    (should polymode-mode)))

(ert-deftest poly-any-jinja2-detects-extensionless-shell-host ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/script.j2")
    (insert "#!/usr/bin/env zsh\n{{ value }}\n")
    (poly-any-jinja2-mode)
    (should (eq major-mode 'sh-mode))
    (should polymode-mode)))

(provide 'poly-any-template-test)
;;; poly-any-template-test.el ends here
