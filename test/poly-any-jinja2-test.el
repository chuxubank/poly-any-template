;;; poly-any-jinja2-test.el --- Tests for poly-any-jinja2 -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'indent-bars)
(require 'poly-any-template)
(require 'poly-any-jinja2)

(ert-deftest poly-any-jinja2-detects-host-mode ()
  (let ((auto-mode-alist '(("\\.host\\'" . text-mode)))
        (magic-mode-alist
         '((poly-any-jinja2-test-undefined-predicate . fundamental-mode))))
    (should (eq (poly-any-template-host-mode-for-file
                 "/tmp/config.host")
                'text-mode))))

(ert-deftest poly-any-template-host-mode-ignores-set-auto-mode-return-value ()
  (cl-letf (((symbol-function 'set-auto-mode)
             (lambda (&rest _)
               (text-mode)
               nil)))
    (should (eq (poly-any-template-host-mode-for-file "/tmp/config.host")
                'text-mode))))

(ert-deftest poly-any-jinja2-configures-inner-mode ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/config.text.j2")
    (poly-any-jinja2-mode)
    (should polymode-mode)
    (should (cl-some
             (lambda (innermode)
               (eq (eieio-oref innermode 'mode) 'jinja2-ts-mode))
             (eieio-oref pm/polymode '-innermodes)))))

(ert-deftest poly-any-jinja2-uses-pure-mode-without-a-host ()
  (dolist (suffix '("j2" "jinja" "jinja2"))
    (with-temp-buffer
      (setq buffer-file-name (format "/tmp/template.%s" suffix))
      (normal-mode t)
      (should (eq major-mode 'jinja2-ts-mode))
      (should-not polymode-mode))))

(ert-deftest poly-any-jinja2-uses-customizable-lighter ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/config.text.j2")
    (poly-any-jinja2-mode)
    (let* ((mode (eieio-oref pm/polymode '-minor-mode))
           (lighter (cadr (assq mode minor-mode-alist))))
      (should (eq lighter 'poly-any-jinja2-lighter))
      (let ((poly-any-jinja2-lighter " Jinja"))
        (should (equal (symbol-value lighter) " Jinja"))))))

(ert-deftest poly-any-jinja2-registers-file-patterns-in-order ()
  (let ((poly-entry
         (cl-position '("\\.\\(?:j2\\|jinja\\|jinja2\\)\\'"
                        . poly-any-jinja2-mode)
                      auto-mode-alist :test #'equal))
        (plain-entry
         (cl-position '("\\.\\(?:j2\\|jinja\\|jinja2\\)\\'"
                        . jinja2-ts-mode)
                      auto-mode-alist :test #'equal)))
    (should poly-entry)
    (should plain-entry)
    (should (< poly-entry plain-entry))))

(ert-deftest poly-any-jinja2-extra-rule-preserves-host-extension ()
  (let ((poly-any-jinja2-extra-file-name-rules
         '("/ansible/.*\\.host\\'"))
        (auto-mode-alist '(("\\.host\\'" . text-mode))))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/ansible/playbook.host")
      (normal-mode t)
      (should (eq major-mode 'text-mode))
      (should polymode-mode))))

(ert-deftest poly-any-jinja2-standard-suffix-is-removed ()
  (should (equal
           (poly-any-template--host-filename "/tmp/config.host.j2" t)
           "/tmp/config.host")))

(ert-deftest poly-any-jinja2-span-includes-delimiters ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/config.text.j2")
    (insert "name={{ render(value) }}")
    (poly-any-jinja2-mode)
    (goto-char (point-min))
    (search-forward "render")
    (let ((span (pm-innermost-span)))
      (should (eq (car span) 'body))
      (should (equal (buffer-substring-no-properties
                      (nth 1 span) (nth 2 span))
                     "{{ render(value) }}")))))

(ert-deftest poly-any-jinja2-fontifies-inner-mode-on-first-pass ()
  (skip-unless (treesit-ready-p 'jinja))
  (let ((treesit-font-lock-level 4))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/config.text.j2")
      (insert "{% if enabled %}{{ render(value) }}{% endif %}")
      (poly-any-jinja2-mode)
      (let ((poly-lock-allow-background-adjustment nil))
        (pm-map-over-spans
         (lambda (_span)
           (setq font-lock-mode t)
           (setq-local poly-lock-allow-fontification t)
           (poly-lock-mode t)))
        (font-lock-ensure))
      (goto-char (point-min))
      (search-forward "if")
      (should (eq (get-text-property (1- (point)) 'face)
                  'font-lock-keyword-face))
      (search-forward "render")
      (should (eq (get-text-property (1- (point)) 'face)
                  'font-lock-function-call-face))
      (search-forward "endif")
      (should (eq (get-text-property (1- (point)) 'face)
                  'font-lock-keyword-face))
      (should-not
       (text-property-search-forward 'face 'font-lock-warning-face t)))))

(ert-deftest poly-any-jinja2-filters-only-artificial-blank-lines ()
  (let ((indent-bars-display-on-blank-lines t))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/config.json.j2")
      (insert "        {% if enabled %}\n"
              "\n"
              "        {% endif %}\n")
      (poly-any-jinja2-mode)
      (should indent-bars-display-on-blank-lines)
      (should (eq indent-bars--display-blank-lines-function
                  #'poly-any-template--indent-bars-display-blank-lines))
      (let ((indent-bars-prefer-character t)
            (original-function
             poly-any-template--indent-bars-blank-line-function)
            calls)
        (indent-bars-mode 1)
        (let ((poly-any-template--indent-bars-blank-line-function
               (lambda (beg end &rest args)
                 (push (cons beg end) calls)
                 (apply original-function beg end args))))
          (funcall indent-bars--display-blank-lines-function
                   (point-min) (point-max)))
        (goto-char (point-min))
        (let ((blank-beg (line-beginning-position 2)))
          (should (equal calls (list (cons blank-beg (1+ blank-beg)))))))
      (goto-char (point-min))
      (let ((action-end (line-end-position 1))
            (blank-end (line-end-position 2)))
        (should-not (get-text-property action-end 'indent-bars-display))
        (should (get-text-property blank-end 'indent-bars-display))))))

(provide 'poly-any-jinja2-test)
;;; poly-any-jinja2-test.el ends here
