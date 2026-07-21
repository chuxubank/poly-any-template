;;; poly-any-go-template-test.el --- Tests for poly-any-go-template -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'indent-bars)
(require 'poly-any-template)
(require 'poly-any-go-template)
(require 'toml-ts-mode nil t)

(ert-deftest poly-any-go-template-configures-inner-mode ()
  (should (eq (eieio-oref poly-any-template-go-innermode 'mode)
              'go-template-ts-mode)))

(ert-deftest poly-any-go-template-uses-pure-mode-without-a-host ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/values.tmpl")
    (poly-any-go-template-mode)
    (should (eq major-mode 'go-template-ts-mode))
    (should-not polymode-mode)))

(ert-deftest poly-any-go-template-uses-customizable-lighter ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/config.text.tmpl")
    (poly-any-go-template-mode)
    (let* ((mode (eieio-oref pm/polymode '-minor-mode))
           (lighter (cadr (assq mode minor-mode-alist))))
      (should (eq lighter 'poly-any-go-template-lighter))
      (let ((poly-any-go-template-lighter " Go"))
        (should (equal (symbol-value lighter) " Go"))))))

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

(ert-deftest poly-any-go-template-extra-rule-preserves-host-extension ()
  (let ((poly-any-go-template-extra-file-name-rules
         '("/modify_[^/]+\\.sh\\'")))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/modify_profile.sh")
      (normal-mode t)
      (should (eq major-mode 'sh-mode))
      (should polymode-mode))))

(ert-deftest poly-any-go-template-standard-suffix-is-removed ()
  (should (equal
           (poly-any-template--host-filename "/tmp/config.sh.tmpl" t)
           "/tmp/config.sh")))

(ert-deftest poly-any-go-template-extra-function-selects-a-template ()
  (let ((poly-any-go-template-extra-file-name-rules
         (list (lambda (filename)
                 (string-match-p "/dot_zprofile\\.tmpl\\'" filename))))
        (poly-any-template-host-filename-functions
         (list (lambda (filename)
                 (replace-regexp-in-string
                  "/dot_zprofile\\'" "/.zprofile" filename)))))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/dot_zprofile.tmpl")
      (normal-mode t)
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

(ert-deftest poly-any-go-template-filters-only-artificial-blank-lines ()
  (let ((indent-bars-display-on-blank-lines t))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/config.json.tmpl")
      (insert "        {{ if .enabled }}\n"
              "\n"
              "        {{ end }}\n")
      (poly-any-go-template-mode)
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

(ert-deftest poly-any-go-template-span-ignores-delimiters-in-strings ()
  (dolist (action '("{{ printf \"}}\" .Name }}"
                    "{{ printf `}}` .Name }}"
                    "{{ printf \"\\\"}}\" .Name }}"))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/config.text.tmpl")
      (insert "name=" action)
      (poly-any-go-template-mode)
      (goto-char (point-min))
      (search-forward ".Name")
      (let ((span (pm-innermost-span)))
        (should (eq (car span) 'body))
        (should (equal (buffer-substring-no-properties
                        (nth 1 span) (nth 2 span))
                       action))))))

(ert-deftest poly-any-go-template-span-ignores-delimiters-in-comments ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/config.text.tmpl")
    (insert "before {{/* literal }} inside */}} after")
    (poly-any-go-template-mode)
    (goto-char (point-min))
    (search-forward "inside")
    (let ((span (pm-innermost-span)))
      (should (eq (car span) 'body))
      (should (equal (buffer-substring-no-properties
                      (nth 1 span) (nth 2 span))
                     "{{/* literal }} inside */}}")))))

(ert-deftest poly-any-go-template-fontifies-host-and-inner-mode ()
  (skip-unless (and (fboundp 'yaml-ts-mode) (treesit-ready-p 'yaml)
                    (treesit-ready-p 'gotmpl)))
  (let ((treesit-font-lock-level 4))
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
      (should (memq (get-text-property (1- (point)) 'face)
                    '(font-lock-builtin-face
                      font-lock-function-call-face)))
      (should-not
       (text-property-search-forward 'face 'font-lock-warning-face t)))))

(ert-deftest poly-any-go-template-fontifies-end-as-keyword ()
  (skip-unless (treesit-ready-p 'gotmpl))
  (let ((treesit-font-lock-level 4))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/config.json.tmpl")
      (insert "{{ end }}\n")
      (poly-any-go-template-mode)
      (let ((poly-lock-allow-background-adjustment nil))
        (pm-map-over-spans
         (lambda (_span)
           (setq font-lock-mode t)
           (setq-local poly-lock-allow-fontification t)
           (poly-lock-mode t)))
        (font-lock-ensure))
      (goto-char (point-min))
      (search-forward "end")
      (should (eq (get-text-property (1- (point)) 'face)
                  'font-lock-keyword-face)))))

(ert-deftest poly-any-go-template-preserves-host-strings-across-inner-spans ()
  (skip-unless (treesit-ready-p 'gotmpl))
  (let ((auto-mode-alist '(("\\.sh\\'" . sh-mode)))
        (treesit-font-lock-level 4))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/script.sh.tmpl")
      (insert "if true; then\n"
              "  echo \"{{ .value }}\"\n"
              "else\n"
              "  echo fallback\n"
              "fi\n")
      (poly-any-go-template-mode)
      (let ((poly-lock-allow-background-adjustment nil))
        (pm-map-over-spans
         (lambda (_span)
           (setq font-lock-mode t)
           (setq-local poly-lock-allow-fontification t)
           (poly-lock-mode t)))
        (font-lock-ensure))
      (goto-char (point-min))
      (forward-line 2)
      (back-to-indentation)
      (should (eq (get-char-property (point) 'face)
                  'font-lock-keyword-face)))))

(ert-deftest poly-any-go-template-protects-host-font-lock-from-inner-spans ()
  (skip-unless (and (fboundp 'toml-ts-mode) (treesit-ready-p 'toml)
                    (treesit-ready-p 'gotmpl)))
  (let ((auto-mode-alist '(("\\.toml\\'" . toml-ts-mode)))
        (treesit-font-lock-level 4))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/common.toml.tmpl")
      (insert "[{{ index .path.cache \"models-dev-api\" | quote }}]\n"
              "type = \"file\"\n"
              "{{ if eq .chezmoi.os \"linux\" }}\n"
              "url = \"https://example.com/{{ .chezmoi.arch }}\"\n"
              "{{ end }}\n")
      (poly-any-go-template-mode)
      (let ((poly-lock-allow-background-adjustment nil))
        (pm-map-over-spans
         (lambda (_span)
           (setq font-lock-mode t)
           (setq-local poly-lock-allow-fontification t)
           (poly-lock-mode t)))
        (font-lock-ensure))
      (let (inner-warning)
        (pm-map-over-spans
         (lambda (span)
           (when (eq (car span) 'body)
             (setq inner-warning
                   (or inner-warning
                       (cl-loop for position from (nth 1 span)
                                below (nth 2 span)
                                thereis
                                (eq (get-char-property position 'face)
                                    'font-lock-warning-face)))))))
        (should-not inner-warning)))))

(provide 'poly-any-go-template-test)
;;; poly-any-go-template-test.el ends here
