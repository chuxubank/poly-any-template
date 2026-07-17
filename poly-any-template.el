;;; poly-any-template.el --- Shared support for template polymodes -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka

;; Author: Misaka <chuxubank@qq.com>
;; Maintainer: Misaka <chuxubank@qq.com>
;; Version: 0.1.0
;; Keywords: languages, polymode, templates
;; URL: https://github.com/chuxubank/poly-any-template

;;; Commentary:

;; Shared support for the independently installable
;; `poly-any-jinja2.el' and `poly-any-go-template.el' packages.

;;; Code:

(require 'polymode)
(require 'subr-x)

(defun poly-any-template--get-major-mode-for-file (filename)
  "Return the major mode selected for FILENAME."
  (when filename
    (ignore-errors
      (with-temp-buffer
        (set-visited-file-name filename t t)
        (set-auto-mode)
        (unless (eq major-mode 'fundamental-mode)
          major-mode)))))

(defun poly-any-template--activate (dialect innermode lighter)
  "Activate a polymode for DIALECT using INNERMODE and LIGHTER."
  (let* ((base-filename (when buffer-file-name
                          (file-name-sans-extension buffer-file-name)))
         (host-major-mode
          (or (poly-any-template--get-major-mode-for-file base-filename)
              'text-mode))
         (host-mode-symbol
          (intern (format "poly-%s-%s-hostmode" host-major-mode dialect)))
         (polymode-symbol
          (intern (format "poly-%s-%s-mode"
                          (string-remove-suffix
                           "-mode" (symbol-name host-major-mode))
                          dialect))))
    (unless (fboundp host-mode-symbol)
      (eval `(define-hostmode ,host-mode-symbol :mode ',host-major-mode) t))
    (unless (fboundp polymode-symbol)
      (eval `(define-polymode ,polymode-symbol
               :hostmode ',host-mode-symbol
               :innermodes '(,innermode)
               :lighter ,lighter) t))
    (funcall polymode-symbol)))

(provide 'poly-any-template)
;;; poly-any-template.el ends here
