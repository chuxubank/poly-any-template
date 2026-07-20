;;; poly-ansible-jinja2.el --- Jinja2 polymode integration for Ansible -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Misaka
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1") (ansible "0") (ansible-doc "0") (poly-any-jinja2 "0.1.11"))
;; Keywords: languages, polymode, templates, ansible
;; URL: https://github.com/chuxubank/poly-any-template

;;; Commentary:

;; Recognize standard Ansible project layouts and compose their YAML or
;; rendered-file host modes with `jinja2-ts-mode'.

;;; Code:

(require 'ansible)
(require 'ansible-doc)
(require 'poly-any-jinja2)

(defgroup poly-ansible-jinja2 nil
  "Jinja2 polymode integration for Ansible projects."
  :group 'poly-any-template
  :prefix "poly-ansible-jinja2-")

(defconst poly-ansible-jinja2--yaml-suffix-regexp
  "\\.ya?ml\\'"
  "Regexp matching YAML file suffixes used by Ansible.")

(defconst poly-ansible-jinja2--jinja-suffix-regexp
  "\\.\\(?:j2\\|jinja\\|jinja2\\)\\'"
  "Regexp matching standard Jinja2 template suffixes.")

(defcustom poly-ansible-jinja2-project-markers
  '("ansible.cfg" ".ansible-lint" "roles" "group_vars" "host_vars"
    "inventory" "inventories" "playbooks")
  "Files and directories that identify an Ansible project root."
  :type '(repeat string)
  :group 'poly-ansible-jinja2)

(defun poly-ansible-jinja2--vars-file-p (filename)
  "Return non-nil when FILENAME is below group_vars or host_vars."
  (and (string-match-p "/\\(?:group_vars\\|host_vars\\)/" filename)
       (not (string-prefix-p "." (file-name-nondirectory filename)))))

(defun poly-ansible-jinja2--project-marker-p (directory)
  "Return non-nil if DIRECTORY has an Ansible project marker."
  (catch 'found
    (dolist (marker poly-ansible-jinja2-project-markers)
      (when (file-exists-p (expand-file-name marker directory))
        (throw 'found t)))))

(defun poly-ansible-jinja2--project-root (filename)
  "Return the marked Ansible project root containing FILENAME."
  (locate-dominating-file
   (file-name-directory filename)
   #'poly-ansible-jinja2--project-marker-p))

(defun poly-ansible-jinja2--template-file-p (filename)
  "Return non-nil when FILENAME follows an Ansible template layout."
  (and (string-match-p "/templates/" filename)
       (or (string-match-p poly-ansible-jinja2--jinja-suffix-regexp
                           filename)
           (string-match-p "/roles/[^/]+/templates/" filename)
           (poly-ansible-jinja2--project-root filename))))

(defun poly-ansible-jinja2--marked-project-yaml-file-p (filename)
  "Return non-nil for YAML FILENAME in a standard project location."
  (when-let ((root (poly-ansible-jinja2--project-root filename)))
    (let ((relative-name (file-relative-name filename root)))
      (or (not (string-match-p "/" relative-name))
          (string-match-p "\\`tasks/" relative-name)))))

(defun poly-ansible-jinja2--layout-yaml-file-p (filename)
  "Return non-nil when YAML FILENAME follows an Ansible directory layout."
  (and (string-match-p poly-ansible-jinja2--yaml-suffix-regexp filename)
       (or (string-match-p
            "/\\(?:ansible\\|inventory\\|inventories\\|molecule\\|playbooks\\)/"
            filename)
           (string-match-p
            "/roles/[^/]+/\\(?:defaults\\|handlers\\|meta\\|tasks\\|vars\\)/"
            filename)
           (poly-ansible-jinja2--marked-project-yaml-file-p filename))))

;;;###autoload
(defun poly-ansible-jinja2-file-p (&optional filename)
  "Return non-nil when FILENAME should use Ansible Jinja2 integration.
When nil, FILENAME defaults to the current buffer's file name."
  (setq filename (or filename buffer-file-name))
  (when filename
    (let ((filename (expand-file-name filename)))
      (or (poly-ansible-jinja2--vars-file-p filename)
          (poly-ansible-jinja2--template-file-p filename)
          (poly-ansible-jinja2--layout-yaml-file-p filename)))))

(defun poly-ansible-jinja2--host-filename (filename)
  "Give an Ansible variable FILENAME an inferable host suffix."
  (if (and filename (poly-ansible-jinja2--vars-file-p filename))
      (let ((extension (file-name-extension filename)))
        (if (and extension
                 (member (downcase extension) '("json" "yaml" "yml")))
            filename
          (concat filename ".yaml")))
    filename))

;;;###autoload
(defun poly-ansible-jinja2-mode ()
  "Edit an Ansible file using Jinja2 within its inferred host mode."
  (interactive)
  (let* ((filename (and buffer-file-name
                        (expand-file-name buffer-file-name)))
         (template-file-p
          (and filename
               (poly-ansible-jinja2--template-file-p filename)))
         (poly-any-jinja2-hostless-mode nil)
         (poly-any-template-host-filename-functions
          (cons #'poly-ansible-jinja2--host-filename
                poly-any-template-host-filename-functions)))
    (poly-any-jinja2-mode)
    (when (and (not template-file-p)
               (derived-mode-p 'yaml-mode 'yaml-ts-mode))
      (ansible-mode 1)
      (ansible-doc-mode 1))))

;;;###autoload
(add-to-list 'magic-mode-alist
             '(poly-ansible-jinja2-file-p . poly-ansible-jinja2-mode))

(provide 'poly-ansible-jinja2)
;;; poly-ansible-jinja2.el ends here
