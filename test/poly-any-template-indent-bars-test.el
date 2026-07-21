;;; poly-any-template-indent-bars-test.el --- indent-bars adapter tests -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'indent-bars)
(require 'poly-any-go-template)
(require 'poly-any-template-indent-bars)

(ert-deftest poly-any-template-indent-bars-keeps-regular-backend-enabled ()
  (let ((indent-bars-treesit-support t)
        (prog-mode-hook '(indent-bars-mode)))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/config.json.tmpl")
      (insert "{{ value }}\n")
      (poly-any-go-template-mode)
      (poly-any-template-indent-bars-mode 1)
      (should indent-bars-mode)
      (should-not indent-bars-treesit-support)
      (should-not indent-bars--font-lock-inhibit)
      (poly-any-template-indent-bars-mode -1)
      (should indent-bars-mode)
      (should indent-bars-treesit-support))))

(ert-deftest poly-any-template-indent-bars-configures-inner-buffers ()
  (let ((indent-bars-treesit-support t)
        (prog-mode-hook '(indent-bars-mode)))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/config.json.tmpl")
      (insert "{{ value }}\n")
      (poly-any-go-template-mode)
      (poly-any-template-indent-bars-mode 1)
      (goto-char (point-min))
      (search-forward "value")
      (with-current-buffer (pm-span-buffer (pm-innermost-span))
        (should indent-bars-mode)
        (should-not indent-bars-treesit-support)
        (should-not indent-bars--font-lock-inhibit)))))

(ert-deftest poly-any-template-indent-bars-filters-artificial-blank-lines ()
  (let ((indent-bars-display-on-blank-lines t)
        (indent-bars-prefer-character t)
        (indent-bars-treesit-support t)
        (prog-mode-hook '(indent-bars-mode)))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/config.json.tmpl")
      (insert "        {{ if .enabled }}\n"
              "\n"
              "        {{ end }}\n")
      (poly-any-go-template-mode)
      (poly-any-template-indent-bars-mode 1)
      (should (eq indent-bars--display-blank-lines-function
                  #'poly-any-template-indent-bars--display-blank-lines))
      (let ((original-function
             poly-any-template-indent-bars--blank-line-function)
            calls)
        (let ((poly-any-template-indent-bars--blank-line-function
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

(ert-deftest poly-any-template-indent-bars-preserves-first-fontification ()
  (skip-unless (treesit-ready-p 'gotmpl))
  (let ((auto-mode-alist '(("\\.sh\\'" . sh-mode)))
        (font-lock-global-modes t)
        (global-font-lock-mode t)
        (indent-bars-treesit-support t)
        (poly-any-template-after-activate-hook
         '(poly-any-template-indent-bars-mode))
        (poly-lock-allow-background-adjustment nil)
        (prog-mode-hook '(indent-bars-mode))
        (treesit-font-lock-level 4))
    (with-temp-buffer
      (setq buffer-file-name "/tmp/script.sh.tmpl")
      (insert "{{ if .enabled }}\n{{ end }}\n")
      (poly-any-go-template-mode)
      (dotimes (_ 3)
        (font-lock-flush)
        (font-lock-ensure))
      (should indent-bars-mode)
      (should-not indent-bars-treesit-support)
      (goto-char (point-min))
      (search-forward "if")
      (should (eq (get-char-property (1- (point)) 'face)
                  'font-lock-keyword-face))
      (search-forward "end")
      (should (eq (get-char-property (1- (point)) 'face)
                  'font-lock-keyword-face)))))

(provide 'poly-any-template-indent-bars-test)
;;; poly-any-template-indent-bars-test.el ends here
