;;; poly-treesit-fold.el --- Use treesit-fold in polymode buffers -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka
;; Version: 0.1.1
;; Package-Requires: ((emacs "29.1") (polymode "0.2") (treesit-fold "20260417.1708"))
;; Keywords: convenience, folding, languages, polymode, tree-sitter
;; URL: https://github.com/chuxubank/poly-any-template

;;; Commentary:

;; Make `treesit-fold' select the tree-sitter parser associated with the
;; current polymode span.  The package also registers folding ranges for
;; `go-template-ts-mode' and `jinja2-ts-mode'.

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
  (when treesit-primary-parser
    (ignore-errors (treesit-parser-root-node treesit-primary-parser))))

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

(defun poly-treesit-fold-range-jinja-block (node offset)
  "Return the fold range for Jinja block NODE using OFFSET."
  (let ((count (treesit-node-child-count node t)))
    (when (> count 1)
      (let ((opening (treesit-node-child node 0 t))
            (closing (treesit-node-child node (1- count) t)))
        (when (<= (treesit-node-end opening) (treesit-node-start closing))
          (cons (+ (treesit-node-end opening) (car offset))
                (+ (treesit-node-start closing) (cdr offset))))))))

(setf (alist-get 'jinja2-ts-mode treesit-fold-range-alist)
      (mapcar (lambda (type)
                (cons type #'poly-treesit-fold-range-jinja-block))
              '(autoescape_block block_block call_block filter_block
                for_block if_block macro_block raw_block set_block
                trans_block with_block)))

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
