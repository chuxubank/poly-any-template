;;; poly-any-template.el --- Shared support for template polymodes -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka

;; Author: Misaka <chuxubank@qq.com>
;; Maintainer: Misaka <chuxubank@qq.com>
;; Version: 0.1.17
;; Package-Requires: ((emacs "29.1") (polymode "0.2"))
;; Keywords: languages, polymode, templates
;; URL: https://github.com/chuxubank/poly-any-template

;;; Commentary:

;; Shared support for the independently installable
;; `poly-any-jinja2.el' and `poly-any-go-template.el' packages.

;;; Code:

(require 'polymode)
(require 'subr-x)

(defgroup poly-any-template nil
  "Shared support for template polymodes."
  :group 'polymode)

(defcustom poly-any-template-host-filename-functions nil
  "Functions that transform a template's inferred host filename.
Each function receives the result of the previous function.  The initial
value is the template filename after removing a recognized template suffix,
when present."
  :type '(repeat function)
  :group 'poly-any-template)

(defvar poly-any-template-after-activate-hook nil
  "Hook run after a poly-any template mode has been activated.")

(defvar-local poly-any-template--indent-bars-blank-line-function nil
  "Original indent-bars blank-line display function for this buffer.")

(defvar-local poly-any-template--poly-lock-requested nil
  "Non-nil when this polymode buffer should initialize Poly-lock.")

(defvar-local poly-any-template--font-lock-managed-p nil
  "Non-nil when Font Lock is managed by a poly-any template mode.")

(defun poly-any-template--indent-bars-filter-blank-lines
    (function beg end &rest args)
  "Call FUNCTION for real blank lines between BEG and END with ARGS.
Polymode hides inner spans while fontifying the host, which makes template
action lines look blank to `indent-bars'."
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

(defun poly-any-template--indent-bars-display-blank-lines
    (beg end &rest args)
  "Display indent bars on real blank lines between BEG and END with ARGS."
  (apply #'poly-any-template--indent-bars-filter-blank-lines
         poly-any-template--indent-bars-blank-line-function beg end args))

(defun poly-any-template--configure-indent-bars ()
  "Configure optional indent-bars integration in the current buffer."
  (let ((current
         (and (boundp 'indent-bars--display-blank-lines-function)
              (symbol-value 'indent-bars--display-blank-lines-function))))
    (unless (eq current
                #'poly-any-template--indent-bars-display-blank-lines)
      (setq-local poly-any-template--indent-bars-blank-line-function
                  (or current 'indent-bars--display-blank-lines)))
    (set (make-local-variable
          'indent-bars--display-blank-lines-function)
         #'poly-any-template--indent-bars-display-blank-lines)))

(defun poly-any-template--extra-file-name-p (filename rules)
  "Return non-nil when FILENAME matches an entry in RULES.
Each rule may be a regexp or a function called with FILENAME."
  (and filename
       (catch 'matched
         (dolist (rule rules)
           (when (if (functionp rule)
                     (funcall rule filename)
                   (string-match-p rule filename))
             (throw 'matched t))))))

(defun poly-any-template--host-filename (filename remove-template-suffix)
  "Return the host filename inferred from template FILENAME.
Remove the final extension when REMOVE-TEMPLATE-SUFFIX is non-nil, then
apply `poly-any-template-host-filename-functions'."
  (let ((host-filename
         (cond ((not filename) nil)
               (remove-template-suffix
                (file-name-sans-extension filename))
               (t filename))))
    (dolist (function poly-any-template-host-filename-functions
                      host-filename)
      (setq host-filename (funcall function host-filename)))))

(defun poly-any-template--lexical-tail-matcher
    (delimiter quote-characters &optional raw-quote-characters block-comment)
  "Find lexical DELIMITER and return a zero-width match.
QUOTE-CHARACTERS is a list of characters that open and close strings.
Backslash escapes the following character inside those strings, except when
the quote character is also present in RAW-QUOTE-CHARACTERS.  BLOCK-COMMENT,
when non-nil, is a cons of its opening and closing strings."
  (let ((delimiter-regexp (regexp-quote delimiter))
        (comment-start-regexp
         (and block-comment (regexp-quote (car block-comment))))
        (comment-end-regexp
         (and block-comment (regexp-quote (cdr block-comment))))
        quote
        in-comment
        found)
    (while (and (not found) (< (point) (point-max)))
      (let ((character (char-after)))
        (cond
         ((and in-comment (looking-at-p comment-end-regexp))
          (forward-char (length (cdr block-comment)))
          (setq in-comment nil))
         (in-comment
          (forward-char 1))
         ((and (not quote) (looking-at-p delimiter-regexp))
          (forward-char (length delimiter))
          (setq found (point)))
         ((and (not quote) comment-start-regexp
               (looking-at-p comment-start-regexp))
          (forward-char (length (car block-comment)))
          (setq in-comment t))
         ((not quote)
          (when (memq character quote-characters)
            (setq quote character))
          (forward-char 1))
         ((and (eq character ?\\)
               (not (memq quote raw-quote-characters)))
          (forward-char (min 2 (- (point-max) (point)))))
         ((eq character quote)
          (setq quote nil)
          (forward-char 1))
         (t
          (forward-char 1)))))
    (when found
      (cons found found))))

(defun poly-any-template--auto-mode-match (filename case-insensitive-p)
  "Return the `auto-mode-alist' value matching FILENAME.
CASE-INSENSITIVE-P describes the filesystem of the original template file."
  (if case-insensitive-p
      (let ((case-fold-search t))
        (assoc-default filename auto-mode-alist #'string-match))
    (or (let ((case-fold-search nil))
          (assoc-default filename auto-mode-alist #'string-match))
        (and auto-mode-case-fold
             (let ((case-fold-search t))
               (assoc-default filename auto-mode-alist #'string-match))))))

(defun poly-any-template--auto-mode-for-file (filename)
  "Return the mode function selected for FILENAME without calling it."
  (let ((name (file-name-sans-versions filename))
        (remote-id (file-remote-p filename))
        (case-insensitive-p (file-name-case-insensitive-p filename))
        mode)
    (when (and (stringp remote-id)
               (string-match (regexp-quote remote-id) name))
      (setq name (substring name (match-end 0))))
    (while name
      (setq mode (poly-any-template--auto-mode-match
                  name case-insensitive-p))
      (if (and (not (functionp mode))
               (consp mode)
               (cadr mode))
          (setq mode (car mode)
                name (substring name 0 (match-beginning 0)))
        (setq name nil)))
    mode))

(defun poly-any-template--remap-mode (mode)
  "Return MODE after major-mode remapping when it remains a named function."
  (let ((remapped
         (if (fboundp 'major-mode-remap)
             (funcall 'major-mode-remap mode)
           (or (cdr (assq mode major-mode-remap-alist)) mode))))
    (when (and (symbolp remapped)
               (functionp remapped)
               (not (eq remapped 'fundamental-mode)))
      remapped)))

(defun poly-any-template--global-font-lock-enabled-p ()
  "Return non-nil when Global Font Lock covers the current major mode."
  (and (bound-and-true-p global-font-lock-mode)
       (cond
        ((eq font-lock-global-modes t))
        ((eq (car-safe font-lock-global-modes) 'not)
         (not (memq major-mode (cdr font-lock-global-modes))))
        ((memq major-mode font-lock-global-modes)))))

(defun poly-any-template--font-lock-mode (function &rest args)
  "Call FUNCTION with ARGS without Font Lock rejecting a hidden buffer.
Emacs refuses to enable Font Lock in buffers whose names start with a space.
Polymode uses such buffers internally even while displaying them, so a later
call from Global Font Lock or another minor mode would otherwise disable
fontification after the initial Poly-lock setup."
  (if (and poly-any-template--font-lock-managed-p
           (string-prefix-p " " (buffer-name)))
      (let ((original-name (buffer-name))
            (temporary-name
             (generate-new-buffer-name
              (format "*%s font-lock*"
                      (string-trim-left (buffer-name))))))
        (unwind-protect
            (progn
              (rename-buffer temporary-name)
              (apply function args))
          (when (buffer-live-p (current-buffer))
            (rename-buffer original-name))))
    (apply function args)))

(defun poly-any-template--indent-bars-font-lock-active-p ()
  "Return non-nil when an owned buffer uses indent-bars Tree-sitter lock."
  (and (boundp 'indent-bars--font-lock-inhibit)
       (catch 'active
         (dolist (buffer (eieio-oref pm/polymode '-buffers))
           (when (and (buffer-live-p buffer)
                      (buffer-local-value
                       'indent-bars--font-lock-inhibit buffer))
             (throw 'active t)))
         nil)))

(defun poly-any-template--keep-inner-font-lock-enabled ()
  "Keep language fontification enabled in a polymode inner buffer.
Indent-bars can normally skip the language fontifier when only indentation
guides need updating.  Polymode fontifies the host first, however, and that
pass can clear face properties shared with inner buffers.  An inner span must
therefore always restore its language faces when Poly-lock visits it."
  (when (and poly-any-template--font-lock-managed-p
             (buffer-base-buffer)
             (boundp 'indent-bars--font-lock-inhibit))
    (setq-local indent-bars--font-lock-inhibit nil)))

(defun poly-any-template--poly-lock-flush (&optional beg end)
  "Flush Poly-lock from BEG to END while updating indent-bars state."
  (let ((beg (or beg (point-min)))
        (end (or end (point-max))))
    (when (poly-any-template--indent-bars-font-lock-active-p)
      (with-silent-modifications
        (put-text-property beg end 'indent-bars-font-lock-pending t)))
    (poly-lock-flush beg end)))

(defun poly-any-template--enable-poly-lock-in-current-buffer ()
  "Enable Poly-lock fontification in the current polymode buffer."
  (setq-local poly-any-template--font-lock-managed-p t)
  (when (buffer-base-buffer)
    (add-hook 'indent-bars-mode-hook
              #'poly-any-template--keep-inner-font-lock-enabled t t)
    (add-hook 'font-lock-mode-hook
              #'poly-any-template--keep-inner-font-lock-enabled t t)
    (poly-any-template--keep-inner-font-lock-enabled))
  (setq font-lock-mode t)
  (setq-local poly-lock-allow-fontification t)
  (poly-lock-mode t)
  (setq-local font-lock-flush-function
              #'poly-any-template--poly-lock-flush
              font-lock-fontify-buffer-function
              #'poly-any-template--poly-lock-flush))

(defun poly-any-template--disable-poly-lock-in-current-buffer ()
  "Disable Poly-lock fontification in the current polymode buffer."
  (setq font-lock-mode nil)
  (setq-local poly-lock-allow-fontification nil)
  (when (bound-and-true-p poly-lock-mode)
    (poly-lock-mode nil)))

(defun poly-any-template--initialize-poly-lock (_type)
  "Initialize Poly-lock in an inner buffer when its base buffer requests it."
  (when-let ((base-buffer (buffer-base-buffer)))
    (when (buffer-local-value
           'poly-any-template--poly-lock-requested base-buffer)
      (poly-any-template--enable-poly-lock-in-current-buffer))))

(defun poly-any-template--sync-poly-lock ()
  "Synchronize Poly-lock after Font Lock changes in the base buffer."
  (when (and (bound-and-true-p polymode-mode)
             (not (buffer-base-buffer)))
    (let ((enabled font-lock-mode))
      (setq-local poly-any-template--poly-lock-requested enabled)
      (dolist (buffer (eieio-oref pm/polymode '-buffers))
        (when (buffer-live-p buffer)
          (with-current-buffer buffer
            (if enabled
                (poly-any-template--enable-poly-lock-in-current-buffer)
              (poly-any-template--disable-poly-lock-in-current-buffer)))))
      (when enabled
        (font-lock-flush)))))

(defun poly-any-template--enable-poly-lock (font-lock-enabled)
  "Enable Poly-lock when FONT-LOCK-ENABLED or Global Font Lock requests it."
  (dolist (innermode (eieio-oref pm/polymode '-innermodes))
    (object-add-to-list
     innermode 'init-functions #'poly-any-template--initialize-poly-lock))
  (add-hook 'font-lock-mode-hook #'poly-any-template--sync-poly-lock nil t)
  (when (or font-lock-enabled font-lock-mode
            (poly-any-template--global-font-lock-enabled-p))
    (setq font-lock-mode t)
    (poly-any-template--sync-poly-lock)))

;;;###autoload
(defun poly-any-template-host-mode-for-file (filename)
  "Return the named mode function selected for FILENAME.
Only `auto-mode-alist' is consulted, and the selected function is not run."
  (when filename
    (ignore-errors
      (when-let ((mode (poly-any-template--auto-mode-for-file filename)))
        (poly-any-template--remap-mode mode)))))

(defun poly-any-template--activate
    (dialect innermode lighter-variable remove-template-suffix
             &optional hostless-mode)
  "Activate a polymode for DIALECT using INNERMODE and LIGHTER-VARIABLE.
REMOVE-TEMPLATE-SUFFIX is passed to `poly-any-template--host-filename'.
When no host mode is inferred, call HOSTLESS-MODE if it is non-nil; otherwise
use `text-mode' as the polymode host."
  (let* ((base-filename
          (poly-any-template--host-filename
           buffer-file-name remove-template-suffix))
         (host-major-mode
          (poly-any-template-host-mode-for-file base-filename)))
    (if (and (not host-major-mode) hostless-mode)
        (funcall hostless-mode)
      (let* ((host-major-mode (or host-major-mode 'text-mode))
             (font-lock-enabled font-lock-mode)
             (host-mode-symbol
              (intern (format "poly-%s-%s-hostmode"
                              host-major-mode dialect)))
             (polymode-symbol
              (intern (format "poly-%s-%s-mode"
                              (string-remove-suffix
                               "-mode" (symbol-name host-major-mode))
                              dialect))))
        (unless (fboundp host-mode-symbol)
          (eval `(define-hostmode ,host-mode-symbol
                   :mode ',host-major-mode)
                t))
        (unless (fboundp polymode-symbol)
          (eval `(define-polymode ,polymode-symbol
                   :hostmode ',host-mode-symbol
                   :innermodes '(,innermode)
                   :lighter ',lighter-variable) t))
        (funcall polymode-symbol)
        (poly-any-template--enable-poly-lock font-lock-enabled)
        (poly-any-template--configure-indent-bars)
        (when (and (bound-and-true-p indent-bars-mode)
                   (fboundp 'jit-lock-refontify))
          (funcall 'jit-lock-refontify))
        (run-hooks 'poly-any-template-after-activate-hook)))))

(unless (advice-member-p #'poly-any-template--font-lock-mode 'font-lock-mode)
  (advice-add 'font-lock-mode :around #'poly-any-template--font-lock-mode))

(provide 'poly-any-template)
;;; poly-any-template.el ends here
