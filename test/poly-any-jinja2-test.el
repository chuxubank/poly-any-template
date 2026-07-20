;;; poly-any-jinja2-test.el --- Tests for poly-any-jinja2 -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'indent-bars)
(require 'poly-any-template)
(require 'poly-any-jinja2)

(ert-deftest poly-any-jinja2-detects-host-mode ()
  (let ((auto-mode-alist '(("\\.host\\'" . text-mode))))
    (should (eq (poly-any-template--get-major-mode-for-file
                 "/tmp/config.host")
                'text-mode))))

(ert-deftest poly-any-jinja2-configures-inner-mode ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/config.text.j2")
    (poly-any-jinja2-mode)
    (should polymode-mode)
    (should (cl-some
             (lambda (innermode)
               (eq (eieio-oref innermode 'mode) 'jinja2-mode))
             (eieio-oref pm/polymode '-innermodes)))))

(ert-deftest poly-any-jinja2-uses-customizable-lighter ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/config.text.j2")
    (poly-any-jinja2-mode)
    (let* ((mode (eieio-oref pm/polymode '-minor-mode))
           (lighter (cadr (assq mode minor-mode-alist))))
      (should (eq lighter 'poly-any-jinja2-lighter))
      (let ((poly-any-jinja2-lighter " Jinja"))
        (should (equal (symbol-value lighter) " Jinja"))))))

(ert-deftest poly-any-jinja2-registers-file-pattern ()
  (should (member '("\\.\\(?:j2\\|jinja2\\)\\'"
                   . poly-any-jinja2-mode)
                  auto-mode-alist)))

(ert-deftest poly-any-jinja2-does-not-invent-bars-for-inner-spans ()
  (let ((indent-bars-display-on-blank-lines t))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/config.json.j2")
      (insert "    {% if enabled %}\n"
              "    {% endif %}\n")
      (poly-any-jinja2-mode)
      (should (local-variable-p 'indent-bars-display-on-blank-lines))
      (should-not indent-bars-display-on-blank-lines)
      (let ((indent-bars-prefer-character t))
        (indent-bars-mode 1)
        (indent-bars--draw-all-bars-between (point-min) (point-max)))
      (goto-char (point-min))
      (should-not (get-text-property (line-end-position)
                                     'indent-bars-display)))))

(provide 'poly-any-jinja2-test)
;;; poly-any-jinja2-test.el ends here
