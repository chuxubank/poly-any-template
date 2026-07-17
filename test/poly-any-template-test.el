;;; poly-any-template-test.el --- Tests for poly-any-template -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'poly-any-template)
(require 'poly-any-jinja2)
(require 'poly-any-go-template)

(ert-deftest poly-any-template-detects-host-mode ()
  (let ((auto-mode-alist '(("\\.host\\'" . text-mode))))
    (should (eq (poly-any-template--get-major-mode-for-file
                 "/tmp/deployment.host")
                'text-mode))))

(ert-deftest poly-any-template-configures-jinja2-inner-mode ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/config.text.j2")
    (poly-any-jinja2-mode)
    (should polymode-mode)
    (should (cl-some
             (lambda (innermode)
               (eq (eieio-oref innermode 'mode) 'jinja2-mode))
             (eieio-oref pm/polymode '-innermodes)))))

(ert-deftest poly-any-template-configures-go-inner-mode ()
  (should (eq (eieio-oref poly-any-template-go-innermode 'mode)
              'go-template-ts-mode)))

(ert-deftest poly-any-template-registers-file-patterns-in-order ()
  (let ((poly-entry (cl-position '("\\.[^./]+\\.gotmpl\\'"
                                  . poly-any-go-template-mode)
                                 auto-mode-alist :test #'equal))
        (plain-entry (cl-position '("\\.gotmpl\\'" . go-template-ts-mode)
                                  auto-mode-alist :test #'equal)))
    (should poly-entry)
    (should plain-entry)
    (should (< poly-entry plain-entry))
    (should (member '("\\.\\(?:j2\\|jinja2\\)\\'"
                     . poly-any-jinja2-mode)
                    auto-mode-alist))))

(ert-deftest poly-any-template-go-span-includes-delimiters ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/deployment.text.gotmpl")
    (insert "name={{ printf \"%s\" .Name }}")
    (poly-any-go-template-mode)
    (goto-char (point-min))
    (search-forward "printf")
    (let ((span (pm-innermost-span)))
      (should (eq (car span) 'body))
      (should (equal (buffer-substring-no-properties
                      (nth 1 span) (nth 2 span))
                     "{{ printf \"%s\" .Name }}")))))

(ert-deftest poly-any-template-fontifies-host-and-go-inner-mode ()
  (skip-unless (and (fboundp 'yaml-ts-mode) (treesit-ready-p 'yaml)
                    (treesit-ready-p 'gotmpl)))
  (with-temp-buffer
    (setq buffer-file-name "/tmp/deployment.yaml.gotmpl")
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

(provide 'poly-any-template-test)
;;; poly-any-template-test.el ends here
