;;; poly-any-template-indent-bars.el --- indent-bars for template polymodes -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka
;; Version: 0.1.19
;; Package-Requires: ((emacs "29.1") (indent-bars "0") (poly-any-template "0.1.19"))
;; Keywords: convenience, languages, polymode, templates
;; URL: https://github.com/chuxubank/poly-any-template

;;; Commentary:

;; Integrate `indent-bars' with template polymodes.  The adapter keeps
;; indentation guides enabled but uses indent-bars' regular font-lock backend;
;; its Tree-sitter optimization can otherwise suppress Poly-lock's language
;; fontifier in indirect buffers.

;;; Code:

(require 'indent-bars)
(require 'indent-bars-ts)
(require 'poly-any-template)

(defgroup poly-any-template-indent-bars nil
  "Display indent-bars correctly in template polymodes."
  :group 'poly-any-template
  :prefix "poly-any-template-indent-bars-")

(defvar-local poly-any-template-indent-bars--configured-p nil)
(defvar-local poly-any-template-indent-bars--treesit-support-local-p nil)
(defvar-local poly-any-template-indent-bars--treesit-support-value nil)
(defvar-local poly-any-template-indent-bars--blank-line-function nil)

(defun poly-any-template-indent-bars--filter-blank-lines
    (function beg end &rest args)
  "Call FUNCTION for real blank lines between BEG and END with ARGS."
  (save-excursion
    (save-restriction
      (widen)
      (save-match-data
        (goto-char beg)
        (let ((limit (min end (point-max))))
          (while (< (point) limit)
            (if (looking-at "[ \t]*\n")
                (let ((run-beg (point)))
                  (while (and (< (point) limit)
                              (looking-at "[ \t]*\n"))
                    (forward-line 1))
                  (let ((run-end (point)))
                    (apply function run-beg run-end args)
                    (goto-char run-end)))
              (forward-line 1))))))))

(defun poly-any-template-indent-bars--display-blank-lines
    (beg end &rest args)
  "Display indent bars on real blank lines between BEG and END with ARGS."
  (apply #'poly-any-template-indent-bars--filter-blank-lines
         poly-any-template-indent-bars--blank-line-function beg end args))

(defun poly-any-template-indent-bars--install-blank-line-filter ()
  "Ignore template actions in indent-bars' blank-line pass."
  (when indent-bars-mode
    (let ((current indent-bars--display-blank-lines-function))
      (unless (eq current
                  #'poly-any-template-indent-bars--display-blank-lines)
        (setq-local poly-any-template-indent-bars--blank-line-function
                    (or current #'indent-bars--display-blank-lines)))
      (setq-local indent-bars--display-blank-lines-function
                  #'poly-any-template-indent-bars--display-blank-lines))))

(defun poly-any-template-indent-bars--reinstall-poly-lock ()
  "Restore Poly-lock functions replaced by indent-bars teardown."
  (when (and (bound-and-true-p polymode-mode) font-lock-mode)
    (setq-local poly-lock-allow-fontification t)
    (poly-lock-mode t)
    (font-lock-flush)))

(defun poly-any-template-indent-bars--configure-buffer (&optional _type)
  "Configure indent-bars in the current polymode buffer."
  (unless poly-any-template-indent-bars--configured-p
    (setq-local poly-any-template-indent-bars--configured-p t
                poly-any-template-indent-bars--treesit-support-local-p
                (local-variable-p 'indent-bars-treesit-support)
                poly-any-template-indent-bars--treesit-support-value
                indent-bars-treesit-support)
    (add-hook 'indent-bars-mode-hook
              #'poly-any-template-indent-bars--install-blank-line-filter nil t)
    (let ((enabled indent-bars-mode))
      (when enabled
        (indent-bars-mode -1))
      ;; The TS backend leaves this finalizer behind when its minor mode exits.
      (remove-hook 'font-lock-mode-hook
                   #'indent-bars-ts--finalize-jit-lock t)
      (indent-bars-ts--teardown)
      (setq-local indent-bars-treesit-support nil)
      (when enabled
        (indent-bars-mode 1)))
    (poly-any-template-indent-bars--install-blank-line-filter)
    (poly-any-template-indent-bars--reinstall-poly-lock)))

(defun poly-any-template-indent-bars--restore-buffer ()
  "Restore indent-bars settings saved in the current buffer."
  (when poly-any-template-indent-bars--configured-p
    (let ((enabled indent-bars-mode)
          (local-p poly-any-template-indent-bars--treesit-support-local-p)
          (value poly-any-template-indent-bars--treesit-support-value))
      (remove-hook 'indent-bars-mode-hook
                   #'poly-any-template-indent-bars--install-blank-line-filter t)
      (when enabled
        (indent-bars-mode -1))
      (if local-p
          (setq-local indent-bars-treesit-support value)
        (kill-local-variable 'indent-bars-treesit-support))
      (kill-local-variable 'indent-bars--display-blank-lines-function)
      (kill-local-variable
       'poly-any-template-indent-bars--blank-line-function)
      (setq-local poly-any-template-indent-bars--configured-p nil)
      (when enabled
        (indent-bars-mode 1)))))

(defun poly-any-template-indent-bars--map-buffers (function)
  "Call FUNCTION in every live buffer owned by the current polymode."
  (dolist (buffer (eieio-oref pm/polymode '-buffers))
    (when (buffer-live-p buffer)
      (with-current-buffer buffer
        (funcall function)))))

(defun poly-any-template-indent-bars--add-inner-initializer ()
  "Configure future indirect buffers created by the current polymode."
  (dolist (innermode (eieio-oref pm/polymode '-innermodes))
    (object-add-to-list
     innermode 'init-functions
     #'poly-any-template-indent-bars--configure-buffer t)))

(defun poly-any-template-indent-bars--remove-inner-initializer ()
  "Stop configuring indirect buffers created by the current polymode."
  (dolist (innermode (eieio-oref pm/polymode '-innermodes))
    (oset innermode init-functions
          (delq #'poly-any-template-indent-bars--configure-buffer
                (eieio-oref innermode 'init-functions)))))

;;;###autoload
(define-minor-mode poly-any-template-indent-bars-mode
  "Integrate indent-bars with the current template polymode."
  :lighter nil
  :group 'poly-any-template-indent-bars
  (unless (bound-and-true-p polymode-mode)
    (setq poly-any-template-indent-bars-mode nil)
    (user-error "This buffer is not using a template polymode"))
  (if poly-any-template-indent-bars-mode
      (progn
        (poly-any-template-indent-bars--add-inner-initializer)
        (poly-any-template-indent-bars--map-buffers
         #'poly-any-template-indent-bars--configure-buffer))
    (poly-any-template-indent-bars--remove-inner-initializer)
    (poly-any-template-indent-bars--map-buffers
     #'poly-any-template-indent-bars--restore-buffer)))

(provide 'poly-any-template-indent-bars)
;;; poly-any-template-indent-bars.el ends here
