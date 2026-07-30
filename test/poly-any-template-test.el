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

(ert-deftest poly-any-go-template-detects-shell-host-after-preamble ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/executable_npx.tmpl")
    (insert "{{- if lookPath \"bunx\" -}}\n"
            "#!/bin/sh\n"
            "exec bunx \"$@\"\n"
            "{{- end -}}\n")
    (poly-any-go-template-mode)
    (should (eq major-mode 'sh-mode))
    (should polymode-mode)))

(ert-deftest poly-any-go-template-does-not-scan-past-host-text ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/example.tmpl")
    (insert "generated example:\n"
            "#!/bin/sh\n"
            "echo example\n")
    (poly-any-go-template-mode)
    (should (eq major-mode 'go-template-ts-mode))
    (should-not polymode-mode)))

(ert-deftest poly-any-jinja2-detects-extensionless-shell-host ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/script.j2")
    (insert "#!/usr/bin/env zsh\n{{ value }}\n")
    (poly-any-jinja2-mode)
    (should (eq major-mode 'sh-mode))
    (should polymode-mode)))

(ert-deftest poly-any-jinja2-detects-shell-host-after-preamble ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/script.j2")
    (insert "{%- if enabled -%}\n"
            "#!/bin/sh\n"
            "echo enabled\n"
            "{%- endif -%}\n")
    (poly-any-jinja2-mode)
    (should (eq major-mode 'sh-mode))
    (should polymode-mode)))

(provide 'poly-any-template-test)
;;; poly-any-template-test.el ends here
