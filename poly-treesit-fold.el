;;; poly-treesit-fold.el --- Use treesit-fold in polymode buffers -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (polymode "0.2") (treesit-fold "20260417.1708"))
;; Keywords: convenience, folding, languages, polymode, tree-sitter
;; URL: https://github.com/chuxubank/poly-any-template

;;; Commentary:

;; Make `treesit-fold' select the tree-sitter parser associated with the
;; current polymode span.  The package also registers folding ranges for
;; `go-template-ts-mode'.

;;; Code:

(require 'cl-lib)
(require 'polymode)
(require 'seq)
(require 'treesit)
(require 'treesit-fold)
(require 'treesit-fold-indicators)

(defgroup poly-treesit-fold nil
  "Use treesit-fold in polymode buffers."
  :group 'polymode
  :prefix "poly-treesit-fold-")

(defcustom poly-treesit-fold-mode-language-alist
  '((go-template-ts-mode . gotmpl)
    (sh-mode . bash))
  "Tree-sitter languages that cannot be inferred from their major modes."
  :type '(alist :key-type symbol :value-type symbol)
  :group 'poly-treesit-fold)

(defvar-local poly-treesit-fold--language-cache nil
  "Alist mapping major modes to compatible parser languages in this buffer.")

(defconst poly-treesit-fold--advised-functions
  '(treesit-fold--foldable-node-at-pos
    treesit-fold-close-all
    treesit-fold-indicators-refresh)
  "Treesit-fold functions that obtain a root node without a language.")

(defun poly-treesit-fold--query-patterns ()
  "Return the fold query patterns for the current major mode."
  (when-let ((ranges (alist-get major-mode treesit-fold-range-alist)))
    (seq-mapcat (lambda (range) `((,(car range)) @name)) ranges)))

(defun poly-treesit-fold--language ()
  "Return the parser language compatible with the current fold rules."
  (or (alist-get major-mode poly-treesit-fold--language-cache)
      (let* ((parsers (treesit-parser-list))
             (languages (mapcar #'treesit-parser-language parsers))
             (mode-name (symbol-name major-mode))
             (expected
              (or (alist-get major-mode poly-treesit-fold-mode-language-alist)
                  (when (string-match "\\`\\(.+\\)-ts-mode\\'" mode-name)
                    (intern (match-string 1 mode-name)))))
             (language
              (if expected
                  (and (memq expected languages) expected)
                (when-let ((patterns (poly-treesit-fold--query-patterns)))
                  (cl-loop for parser in parsers
                           for candidate = (treesit-parser-language parser)
                           when (ignore-errors
                                  (treesit-query-compile candidate patterns))
                           return candidate)))))
        (when language
          (push (cons major-mode language)
                poly-treesit-fold--language-cache)
          language))))

(defun poly-treesit-fold--root-node ()
  "Return the parser root node compatible with the current fold rules."
  (when-let ((language (poly-treesit-fold--language)))
    (ignore-errors (treesit-buffer-root-node language))))

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

(defun poly-treesit-fold-range-go-template-action (node offset)
  "Return the fold range for Go-template action NODE using OFFSET."
  (let (begin end)
    (dotimes (index (treesit-node-child-count node))
      (let* ((child (treesit-node-child node index))
             (type (treesit-node-type child)))
        (when (and (not begin) (member type '("}}" "-}}")))
          (setq begin (treesit-node-end child)))
        (when (member type '("{{" "{{-"))
          (setq end (treesit-node-start child)))))
    (when (and begin end (<= begin end))
      (cons (+ begin (car offset)) (+ end (cdr offset))))))

(setf (alist-get 'go-template-ts-mode treesit-fold-range-alist)
      (mapcar (lambda (type)
                (cons type #'poly-treesit-fold-range-go-template-action))
              '(if_action range_action with_action
                define_action block_action)))

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
