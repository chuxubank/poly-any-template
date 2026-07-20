;;; poly-treesit-fold.el --- Use treesit-fold in polymode buffers -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka
;; Version: 0.1.4
;; Package-Requires: ((emacs "29.1") (polymode "0.2") (treesit-fold "20260417.1708"))
;; Keywords: convenience, folding, languages, polymode, tree-sitter
;; URL: https://github.com/chuxubank/poly-any-template

;;; Commentary:

;; Make `treesit-fold' select the Tree-sitter parser associated with the
;; current polymode span.  Language modes remain responsible for registering
;; their own folding ranges.

;;; Code:

(require 'cl-lib)
(require 'polymode)
(require 'treesit)
(require 'treesit-fold)
(require 'treesit-fold-indicators)

(defgroup poly-treesit-fold nil
  "Use treesit-fold in polymode buffers."
  :group 'polymode
  :prefix "poly-treesit-fold-")

(defconst poly-treesit-fold--advised-functions
  '(treesit-fold--foldable-node-at-pos
    treesit-fold-close-all
    treesit-fold-indicators-refresh)
  "Treesit-fold functions that obtain a root node without a language.")

(defun poly-treesit-fold--root-node ()
  "Return the root node of the current span's primary parser."
  (when-let ((parser
              (or (and (boundp 'treesit-primary-parser)
                       (symbol-value 'treesit-primary-parser))
                  (car (treesit-parser-list)))))
    (ignore-errors (treesit-parser-root-node parser))))

(defun poly-treesit-fold--with-parser (function &rest args)
  "Call FUNCTION with ARGS using the parser matching the polymode span."
  (if (not (bound-and-true-p polymode-mode))
      (apply function args)
    (when-let ((root (poly-treesit-fold--root-node)))
      (let ((root-function (symbol-function 'treesit-buffer-root-node)))
        (cl-letf (((symbol-function 'treesit-buffer-root-node)
                   (lambda (&optional language tag)
                     (if language
                         (funcall root-function language tag)
                       root))))
          (apply function args))))))

;;;###autoload
(define-minor-mode poly-treesit-fold-mode
  "Use the tree-sitter parser associated with each polymode span."
  :global t
  :group 'poly-treesit-fold
  (dolist (function poly-treesit-fold--advised-functions)
    (if poly-treesit-fold-mode
        (unless (advice-member-p #'poly-treesit-fold--with-parser function)
          (advice-add function :around #'poly-treesit-fold--with-parser))
      (when (advice-member-p #'poly-treesit-fold--with-parser function)
        (advice-remove function #'poly-treesit-fold--with-parser)))))

(provide 'poly-treesit-fold)
;;; poly-treesit-fold.el ends here
