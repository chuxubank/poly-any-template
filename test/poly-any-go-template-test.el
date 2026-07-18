;;; poly-any-go-template-test.el --- Tests for poly-any-go-template -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'poly-any-template)
(require 'poly-any-go-template)

(ert-deftest poly-any-go-template-configures-inner-mode ()
  (should (eq (eieio-oref poly-any-template-go-innermode 'mode)
              'go-template-ts-mode)))

(ert-deftest poly-any-go-template-registers-file-patterns-in-order ()
  (let ((poly-entry (cl-position '("\\.[^./]+\\.\\(?:gotmpl\\|tmpl\\)\\'"
                                  . poly-any-go-template-mode)
                                 auto-mode-alist :test #'equal))
        (plain-entry (cl-position '("\\.\\(?:gotmpl\\|tmpl\\)\\'"
                                   . go-template-ts-mode)
                                  auto-mode-alist :test #'equal)))
    (should poly-entry)
    (should plain-entry)
    (should (< poly-entry plain-entry))))

(ert-deftest poly-any-go-template-matches-tmpl-compound-files ()
  (let ((pattern (caar (cl-member '("\\.[^./]+\\.\\(?:gotmpl\\|tmpl\\)\\'"
                                    . poly-any-go-template-mode)
                                  auto-mode-alist :test #'equal))))
    (should (string-match-p pattern "deployment.yaml.gotmpl"))
    (should (string-match-p pattern "deployment.yaml.tmpl"))))

(ert-deftest poly-any-go-template-applies-host-filename-functions ()
  (let ((poly-any-template-host-filename-functions
         (list (lambda (filename)
                 (replace-regexp-in-string
                  "/dot_\\([^/]+\\)\\'" "/.\\1" filename)))))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/dot_zprofile.tmpl")
      (poly-any-go-template-mode)
      (should (eq major-mode 'sh-mode))
      (should polymode-mode))))

(ert-deftest poly-any-go-template-runs-after-activate-hook ()
  (let ((poly-any-template-after-activate-hook nil)
        activated)
    (add-hook 'poly-any-template-after-activate-hook
              (lambda () (setq activated t)))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/deployment.yaml.tmpl")
      (poly-any-go-template-mode))
    (should activated)))

(ert-deftest poly-any-go-template-span-includes-delimiters ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/deployment.text.tmpl")
    (insert "name={{ printf \"%s\" .Name }}")
    (poly-any-go-template-mode)
    (goto-char (point-min))
    (search-forward "printf")
    (let ((span (pm-innermost-span)))
      (should (eq (car span) 'body))
      (should (equal (buffer-substring-no-properties
                      (nth 1 span) (nth 2 span))
                     "{{ printf \"%s\" .Name }}")))))

(ert-deftest poly-any-go-template-fontifies-host-and-inner-mode ()
  (skip-unless (and (fboundp 'yaml-ts-mode) (treesit-ready-p 'yaml)
                    (treesit-ready-p 'gotmpl)))
  (with-temp-buffer
    (setq buffer-file-name "/tmp/deployment.yaml.tmpl")
    (insert "name: {{ printf \"%s\" .Release.Name }}\n")
    (poly-any-go-template-mode)
    (let ((poly-lock-allow-background-adjustment nil))
      (pm-map-over-spans
       (lambda (_span)
         (setq font-lock-mode t)
         (setq-local poly-lock-allow-fontification t)
         (poly-lock-mode t)))
      (font-lock-ensure))
    (goto-char (point-min))
    (search-forward "name")
    (should (eq (get-text-property (1- (point)) 'face)
                'font-lock-property-use-face))
    (search-forward "printf")
    (should (eq (get-text-property (1- (point)) 'face)
                'font-lock-builtin-face))))

(provide 'poly-any-go-template-test)
;;; poly-any-go-template-test.el ends here
