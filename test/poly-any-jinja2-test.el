;;; poly-any-jinja2-test.el --- Tests for poly-any-jinja2 -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'indent-bars)
(require 'poly-any-template)
(require 'poly-any-jinja2)

(defvar poly-any-template-test-host-hook-count 0)

(defun poly-any-template-test-count-host-hook ()
  "Count a host-mode hook invocation during a template test."
  (cl-incf poly-any-template-test-host-hook-count))

(defvar poly-any-template-test-selector-count 0)

(defun poly-any-template-test-host-selector ()
  "Select text mode and count the selector invocation."
  (cl-incf poly-any-template-test-selector-count)
  (text-mode))

(ert-deftest poly-any-jinja2-detects-host-mode ()
  (let ((auto-mode-alist '(("\\.host\\'" . text-mode)))
        (magic-mode-alist
         '((poly-any-jinja2-test-undefined-predicate . fundamental-mode))))
    (should (eq (poly-any-template-host-mode-for-file
                 "/tmp/config.host")
                'text-mode))))

(ert-deftest poly-any-template-host-mode-does-not-run-the-mode ()
  (let ((auto-mode-alist '(("\\.host\\'" . text-mode))))
    (cl-letf (((symbol-function 'set-auto-mode)
               (lambda (&rest _)
                 (ert-fail "Host inference called set-auto-mode"))))
      (should (eq (poly-any-template-host-mode-for-file "/tmp/config.host")
                  'text-mode)))))

(ert-deftest poly-any-template-host-mode-supports-suffix-chaining ()
  (let ((auto-mode-alist '(("\\.wrapped\\'" nil t)
                           ("\\.host\\'" . text-mode))))
    (should (eq (poly-any-template-host-mode-for-file
                 "/tmp/config.host.wrapped")
                'text-mode))))

(ert-deftest poly-any-template-host-mode-keeps-remote-case-sensitivity ()
  (let ((auto-mode-alist '(("CASE\\.host\\'" . text-mode)))
        (auto-mode-case-fold nil)
        (filename "/ssh:user@example.test:/tmp/case.host")
        checked-filenames)
    (require 'tramp)
    (cl-letf (((symbol-function 'file-remote-p)
               (lambda (_filename) "/ssh:user@example.test:"))
              ((symbol-function 'file-name-case-insensitive-p)
               (lambda (candidate)
                 (push candidate checked-filenames)
                 nil)))
      (should-not (poly-any-template-host-mode-for-file filename))
      (should (member filename checked-filenames))
      (should-not (member "/tmp/case.host" checked-filenames)))))

(ert-deftest poly-any-template-host-mode-applies-symbol-remapping ()
  (let ((auto-mode-alist '(("\\.host\\'" . text-mode)))
        (major-mode-remap-alist '((text-mode . prog-mode)))
        (major-mode-remap-defaults nil))
    (should (eq (poly-any-template-host-mode-for-file "/tmp/config.host")
                'prog-mode))))

(ert-deftest poly-any-template-host-mode-recognizes-special-filenames ()
  (let ((major-mode-remap-alist nil)
        (major-mode-remap-defaults nil))
    (should (eq (poly-any-template-host-mode-for-file "/tmp/Brewfile")
                'ruby-mode))
    (should (eq (poly-any-template-host-mode-for-file "/tmp/.zprofile")
                'sh-mode))))

(ert-deftest poly-any-template-runs-host-mode-hook-once ()
  (let ((auto-mode-alist '(("\\.host\\'" . text-mode)))
        (poly-any-template-test-host-hook-count 0)
        (text-mode-hook '(poly-any-template-test-count-host-hook)))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/config.host.j2")
      (poly-any-jinja2-mode)
      (should polymode-mode)
      (should (= poly-any-template-test-host-hook-count 1)))))

(ert-deftest poly-any-jinja2-fontifies-on-first-activation ()
  (skip-unless (treesit-ready-p 'jinja))
  (let ((auto-mode-alist '(("\\.sh\\'" . sh-mode)))
        (font-lock-global-modes t)
        (global-font-lock-mode t)
        (poly-lock-allow-background-adjustment nil)
        (treesit-font-lock-level 4))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/script.sh.j2")
      (insert "echo before\n"
              "{{ value }}\n")
      (poly-any-jinja2-mode)
      (dotimes (_ 3)
        (font-lock-flush)
        (font-lock-ensure))
      (goto-char (point-min))
      (search-forward "value")
      (should (bound-and-true-p poly-lock-mode))
      (with-current-buffer
          (pm-span-buffer (pm-innermost-span (1- (point))))
        (should (bound-and-true-p poly-lock-mode)))
      (should (eq (get-char-property (1- (point)) 'face)
                  'font-lock-variable-use-face)))))

(ert-deftest poly-any-template-defers-named-host-selector ()
  (let ((auto-mode-alist
         '(("\\.selected\\'" . poly-any-template-test-host-selector)))
        (poly-any-template-test-selector-count 0))
    (should (eq (poly-any-template-host-mode-for-file
                 "/tmp/config.selected")
                'poly-any-template-test-host-selector))
    (should (= poly-any-template-test-selector-count 0))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/config.selected.j2")
      (poly-any-jinja2-mode)
      (should polymode-mode)
      (should (= poly-any-template-test-selector-count 1)))))

(ert-deftest poly-any-template-rejects-unnamed-or-fundamental-hosts ()
  (let ((auto-mode-alist
         `(("\\.anonymous\\'" . ,(lambda (&optional _argument) (text-mode)))
           ("\\.unknown\\'" . poly-any-template-test-unknown-mode)
           ("\\.fundamental\\'" . fundamental-mode))))
    (dolist (filename '("/tmp/config.anonymous"
                        "/tmp/config.unknown"
                        "/tmp/config.fundamental"))
      (should-not (poly-any-template-host-mode-for-file filename)))))

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

(ert-deftest poly-any-jinja2-supports-a-text-hostless-mode ()
  (let ((poly-any-jinja2-hostless-mode nil))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/template.j2")
      (normal-mode t)
      (should (eq major-mode 'text-mode))
      (should polymode-mode))))

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

(ert-deftest poly-any-jinja2-span-ignores-delimiters-in-strings ()
  (dolist (tag '("{{ \"}}\" ~ value }}"
                 "{{ '}}' ~ value }}"
                 "{{ \"%}\" ~ value }}"
                 "{% set marker = \"%}\" %}"
                 "{% set marker = '%}' %}"
                 "{% set marker = \"}}\" %}"
                 "{{ \"\\\"}}\" ~ value }}"))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/config.text.j2")
      (insert "name=" tag)
      (poly-any-jinja2-mode)
      (goto-char (point-min))
      (search-forward (if (string-match-p "value" tag)
                          "value"
                        "marker"))
      (let ((span (pm-innermost-span)))
        (should (eq (car span) 'body))
        (should (equal (buffer-substring-no-properties
                        (nth 1 span) (nth 2 span))
                       tag))))))

(ert-deftest poly-any-jinja2-comment-uses-its-corresponding-delimiter ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/config.text.j2")
    (insert "before {# literal }} / %} #} after")
    (poly-any-jinja2-mode)
    (goto-char (point-min))
    (search-forward "literal")
    (let ((span (pm-innermost-span)))
      (should (eq (car span) 'body))
      (should (equal (buffer-substring-no-properties
                      (nth 1 span) (nth 2 span))
                     "{# literal }} / %} #}")))))

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
