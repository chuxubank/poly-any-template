;;; poly-ansible-jinja2-test.el --- Tests for poly-ansible-jinja2 -*- lexical-binding: t; no-byte-compile: t; -*-

;;; Code:

(require 'ert)
(require 'poly-ansible-jinja2)

(ert-deftest poly-ansible-jinja2-recognizes-standard-layouts ()
  (dolist (filename '("/tmp/ansible/playbook.yaml"
                      "/tmp/inventory/group_vars/all"
                      "/tmp/inventories/production/host_vars/web.yml"
                      "/tmp/inventories/production/host_vars/db.example.com"
                      "/tmp/roles/web/defaults/main.yml"
                      "/tmp/roles/web/handlers/main.yml"
                      "/tmp/roles/web/meta/main.yml"
                      "/tmp/roles/web/tasks/main.yml"
                      "/tmp/roles/web/vars/main.yml"
                      "/tmp/roles/web/templates/service.conf"
                      "/tmp/templates/env.j2"
                      "/tmp/playbooks/deploy.yml"
                      "/tmp/molecule/default/converge.yml"))
    (should (poly-ansible-jinja2-file-p filename))))

(ert-deftest poly-ansible-jinja2-ignores-hidden-vars-metadata ()
  (dolist (filename '("/tmp/group_vars/.gitkeep"
                      "/tmp/host_vars/.dir-locals.el"))
    (should-not (poly-ansible-jinja2-file-p filename))))

(ert-deftest poly-ansible-jinja2-ignores-non-ansible-files ()
  (cl-letf (((symbol-function 'poly-ansible-jinja2--project-root)
             (lambda (_filename) nil)))
    (dolist (filename '("/tmp/template.j2"
                        "/tmp/config.yml"
                        "/tmp/templates/index.html"
                        "/tmp/templates/logo.png"
                        "/tmp/roles/web/files/static.txt"
                        "/tmp/library/module.py"
                        "/tmp/filter_plugins/custom.py"
                        "/tmp/config.tmpl"))
      (should-not (poly-ansible-jinja2-file-p filename)))))

(ert-deftest poly-ansible-jinja2-ignores-unrelated-project-yaml ()
  (let* ((directory (make-temp-file "poly-ansible-jinja2-" t))
         (marker (expand-file-name "ansible.cfg" directory))
         (workflow-directory
          (expand-file-name ".github/workflows" directory))
         (workflow (expand-file-name "ci.yml" workflow-directory))
         (kubernetes-directory (expand-file-name "kubernetes" directory))
         (manifest (expand-file-name "deployment.yml" kubernetes-directory)))
    (unwind-protect
        (progn
          (write-region "" nil marker nil 'silent)
          (make-directory workflow-directory t)
          (make-directory kubernetes-directory)
          (should-not (poly-ansible-jinja2-file-p workflow))
          (should-not (poly-ansible-jinja2-file-p manifest)))
      (delete-directory directory t))))

(ert-deftest poly-ansible-jinja2-infers-template-hosts ()
  (dolist (case '(("/tmp/templates/env.j2" . text-mode)
                  ("/tmp/roles/web/templates/env.j2" . text-mode)
                  ("/tmp/templates/nginx.conf.j2" . conf-mode)
                  ("/tmp/roles/web/templates/service.conf" . conf-mode)
                  ("/tmp/roles/web/templates/script.sh.j2" . sh-mode)
                  ("/tmp/roles/web/templates/Brewfile.j2" . ruby-mode)))
    (with-temp-buffer
      (setq buffer-file-name (car case))
      (normal-mode t)
      (should (derived-mode-p (cdr case)))
      (should polymode-mode)
      (should (cl-some
               (lambda (innermode)
                 (eq (eieio-oref innermode 'mode) 'jinja2-ts-mode))
               (eieio-oref pm/polymode '-innermodes))))))

(ert-deftest poly-ansible-jinja2-infers-json-template-host ()
  (with-temp-buffer
    (setq buffer-file-name
          "/tmp/roles/web/templates/config.json.j2")
    (normal-mode t)
    (should (memq major-mode '(js-json-mode json-mode json-ts-mode)))
    (should polymode-mode)))

(ert-deftest poly-ansible-jinja2-enables-helpers-for-yaml-sources ()
  (dolist (filename '("/tmp/ansible/playbook.yaml"
                      "/tmp/inventory/group_vars/all"
                      "/tmp/inventories/production/host_vars/web.yml"
                      "/tmp/inventories/production/host_vars/db.example.com"
                      "/tmp/roles/web/tasks/main.yml"
                      "/tmp/playbooks/deploy.yml"
                      "/tmp/molecule/default/converge.yml"))
    (with-temp-buffer
      (setq buffer-file-name filename)
      (normal-mode t)
      (should (derived-mode-p 'yaml-mode 'yaml-ts-mode))
      (should polymode-mode)
      (should ansible-mode)
      (should ansible-doc-mode))))

(ert-deftest poly-ansible-jinja2-does-not-enable-yaml-helpers-for-templates ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/roles/web/templates/config.yaml.j2")
    (normal-mode t)
    (should (derived-mode-p 'yaml-mode 'yaml-ts-mode))
    (should polymode-mode)
    (should-not ansible-mode)
    (should-not ansible-doc-mode)))

(ert-deftest poly-ansible-jinja2-recognizes-marked-project-playbooks ()
  (dolist (marker poly-ansible-jinja2-project-markers)
    (let* ((directory (make-temp-file "poly-ansible-jinja2-" t))
           (marker-path (expand-file-name marker directory))
           (filename (expand-file-name "site.yml" directory))
           (tasks-directory (expand-file-name "tasks" directory))
           (task-filename
            (expand-file-name "webservers-extra.yml" tasks-directory)))
      (unwind-protect
          (progn
            (if (string-match-p "\\." (file-name-nondirectory marker))
                (write-region "" nil marker-path nil 'silent)
              (make-directory marker-path))
            (should (poly-ansible-jinja2-file-p filename))
            (with-temp-buffer
              (setq buffer-file-name filename)
              (normal-mode t)
              (should (derived-mode-p 'yaml-mode 'yaml-ts-mode))
              (should polymode-mode)
              (should ansible-mode)
              (should ansible-doc-mode))
            (make-directory tasks-directory)
            (should (poly-ansible-jinja2-file-p task-filename)))
        (delete-directory directory t)))))

(ert-deftest poly-ansible-jinja2-leaves-project-marker-files-alone ()
  (let* ((directory (make-temp-file "poly-ansible-jinja2-" t))
         (filename (expand-file-name "ansible.cfg" directory)))
    (unwind-protect
        (progn
          (write-region "" nil filename nil 'silent)
          (should-not (poly-ansible-jinja2-file-p filename))
          (with-temp-buffer
            (setq buffer-file-name filename)
            (normal-mode t)
            (should-not polymode-mode)))
      (delete-directory directory t))))

(ert-deftest poly-ansible-jinja2-keeps-ordinary-jinja2-hostless-mode ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/template.j2")
    (normal-mode t)
    (should (eq major-mode 'jinja2-ts-mode))
    (should-not polymode-mode)))

(ert-deftest poly-ansible-jinja2-keeps-go-template-selection ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/config.toml.tmpl")
    (normal-mode t)
    (should polymode-mode)
    (should (cl-some
             (lambda (innermode)
               (eq (eieio-oref innermode 'mode) 'go-template-ts-mode))
             (eieio-oref pm/polymode '-innermodes)))))

(provide 'poly-ansible-jinja2-test)
;;; poly-ansible-jinja2-test.el ends here
