;;; poly-any-jinja2-test.el --- Tests for poly-any-jinja2 -*- lexical-binding: t; -*-

;;; Code:

(require 'ert)
(require 'poly-any-template)
(require 'poly-any-jinja2)

(ert-deftest poly-any-jinja2-detects-host-mode ()
  (let ((auto-mode-alist '(("\\.host\\'" . text-mode))))
    (should (eq (poly-any-template--get-major-mode-for-file
                 "/tmp/config.host")
                'text-mode))))

(ert-deftest poly-any-jinja2-configures-inner-mode ()
  (with-temp-buffer
    (setq buffer-file-name "/tmp/config.text.j2")
    (poly-any-jinja2-mode)
    (should polymode-mode)
    (should (cl-some
             (lambda (innermode)
               (eq (eieio-oref innermode 'mode) 'jinja2-mode))
             (eieio-oref pm/polymode '-innermodes)))))

(ert-deftest poly-any-jinja2-registers-file-pattern ()
  (should (member '("\\.\\(?:j2\\|jinja2\\)\\'"
                   . poly-any-jinja2-mode)
                  auto-mode-alist)))

(ert-deftest poly-any-jinja2-registers-ansible-file-patterns ()
  (dolist (entry '(("/ansible/.*\\.ya?ml\\'" . poly-any-ansible-mode)
                   ("/\\(?:group\\|host\\)_vars/" . poly-any-ansible-mode)))
    (should (member entry auto-mode-alist))))

(ert-deftest poly-any-ansible-configures-yaml-host-and-minor-modes ()
  (let ((auto-mode-alist '(("\\.ya?ml\\'" . yaml-mode)))
        ansible-mode-enabled
        ansible-doc-mode-enabled)
    (cl-letf (((symbol-function 'ansible-mode)
               (lambda (arg) (setq ansible-mode-enabled arg)))
              ((symbol-function 'ansible-doc-mode)
               (lambda (arg) (setq ansible-doc-mode-enabled arg))))
      (with-temp-buffer
        (setq buffer-file-name "/tmp/ansible/playbook.yaml")
        (poly-any-ansible-mode)
        (should (eq major-mode 'yaml-mode))
        (should polymode-mode)
        (should (eq ansible-mode-enabled 1))
        (should (eq ansible-doc-mode-enabled 1))))))

(provide 'poly-any-jinja2-test)
;;; poly-any-jinja2-test.el ends here
