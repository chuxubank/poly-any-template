EMACS ?= emacs
BATCH = $(EMACS) -Q --batch
JINJA2_TS_MODE_PATH ?= ../jinja2-ts-mode
SHARED_DIR = lisp/shared
JINJA2_DIR = lisp/jinja2
ANSIBLE_DIR = lisp/ansible
GO_TEMPLATE_DIR = lisp/go-template
INDENT_BARS_DIR = lisp/indent-bars
TREESIT_FOLD_DIR = lisp/treesit-fold
LOAD_PATH = -L $(SHARED_DIR) -L $(JINJA2_DIR) -L $(ANSIBLE_DIR) \
	-L $(GO_TEMPLATE_DIR) -L $(INDENT_BARS_DIR) \
	-L $(TREESIT_FOLD_DIR) -L test -L $(JINJA2_TS_MODE_PATH)
GO_TEMPLATE_URL = https://github.com/chuxubank/go-template-ts-mode
JINJA2_TS_MODE_URL = https://github.com/chuxubank/jinja2-ts-mode

SOURCES = $(SHARED_DIR)/poly-any-template.el \
	$(JINJA2_DIR)/poly-any-jinja2.el \
	$(ANSIBLE_DIR)/poly-ansible-jinja2.el \
	$(GO_TEMPLATE_DIR)/poly-any-go-template.el \
	$(INDENT_BARS_DIR)/poly-any-template-indent-bars.el \
	$(TREESIT_FOLD_DIR)/poly-treesit-fold.el
AUTOLOADS = $(SHARED_DIR)/poly-any-template-autoloads.el \
	$(JINJA2_DIR)/poly-any-jinja2-autoloads.el \
	$(ANSIBLE_DIR)/poly-ansible-jinja2-autoloads.el \
	$(GO_TEMPLATE_DIR)/poly-any-go-template-autoloads.el \
	$(INDENT_BARS_DIR)/poly-any-template-indent-bars-autoloads.el \
	$(TREESIT_FOLD_DIR)/poly-treesit-fold-autoloads.el

PACKAGE_SETUP = \
	--eval "(require 'package)" \
	--eval "(package-initialize)" \
	--eval "(setq load-prefer-newer t)" \
	--eval "(when (file-directory-p \"$(JINJA2_TS_MODE_PATH)/.tree-sitter\") (add-to-list 'treesit-extra-load-path \"$(JINJA2_TS_MODE_PATH)/.tree-sitter\"))" \
	--eval "(dolist (directory '(\"$(CURDIR)/$(SHARED_DIR)\" \"$(CURDIR)/$(JINJA2_DIR)\" \"$(CURDIR)/$(ANSIBLE_DIR)\" \"$(CURDIR)/$(GO_TEMPLATE_DIR)\" \"$(CURDIR)/$(INDENT_BARS_DIR)\" \"$(CURDIR)/$(TREESIT_FOLD_DIR)\")) (setq load-path (cons directory (delete directory load-path))))" \
	--eval "(setq load-path (cons \"$(CURDIR)/test\" (delete \"$(CURDIR)/test\" load-path)))" \
	--eval "(dolist (file '(\"$(CURDIR)/$(SHARED_DIR)/poly-any-template-autoloads.el\" \"$(CURDIR)/$(JINJA2_DIR)/poly-any-jinja2-autoloads.el\" \"$(CURDIR)/$(ANSIBLE_DIR)/poly-ansible-jinja2-autoloads.el\" \"$(CURDIR)/$(GO_TEMPLATE_DIR)/poly-any-go-template-autoloads.el\" \"$(CURDIR)/$(INDENT_BARS_DIR)/poly-any-template-indent-bars-autoloads.el\" \"$(CURDIR)/$(TREESIT_FOLD_DIR)/poly-treesit-fold-autoloads.el\")) (load file nil t))"

ARCHIVES = \
	--eval "(require 'package)" \
	--eval "(add-to-list 'package-archives '(\"melpa\" . \"https://melpa.org/packages/\") t)" \
	--eval "(add-to-list 'package-archives '(\"jcs-elpa\" . \"https://jcs-emacs.github.io/jcs-elpa/packages/\") t)" \
	--eval "(package-initialize)"

.PHONY: all install-deps autoloads compile check-grammars test test-jinja2 \
	test-ansible test-go-template test-indent-bars test-treesit-fold clean

all: compile test

install-deps:
	$(BATCH) $(ARCHIVES) \
		--eval "(package-refresh-contents)" \
		--eval "(package-install 'polymode)" \
		--eval "(package-install 'indent-bars)" \
		--eval "(package-install 'treesit-fold)" \
		--eval "(package-install 'ansible)" \
		--eval "(package-install 'ansible-doc)" \
		--eval "(package-install 'yaml-mode)" \
		--eval "(unless (package-installed-p 'go-template-ts-mode) (package-vc-install \"$(GO_TEMPLATE_URL)\"))" \
		--eval "(unless (package-installed-p 'jinja2-ts-mode) (package-vc-install \"$(JINJA2_TS_MODE_URL)\"))" \
		--eval "(require 'jinja2-ts-mode)" \
		--eval "(unless (treesit-language-available-p 'jinja) (jinja2-ts-mode-install-grammar))" \
		--eval "(require 'go-template-ts-mode)" \
		--eval "(unless (treesit-language-available-p 'gotmpl) (go-template-ts-mode-install-grammar))" \
		--eval "(setf (alist-get 'yaml treesit-language-source-alist) '(\"https://github.com/tree-sitter-grammars/tree-sitter-yaml\" \"v0.7.2\"))" \
		--eval "(setf (alist-get 'toml treesit-language-source-alist) '(\"https://github.com/tree-sitter-grammars/tree-sitter-toml\"))" \
		--eval "(dolist (language '(yaml toml)) (unless (treesit-language-available-p language) (treesit-install-language-grammar language)))"

autoloads:
	rm -f $(AUTOLOADS)
	$(BATCH) --eval "(require 'package)" \
		--eval "(package-generate-autoloads 'poly-any-template \"$(SHARED_DIR)\")" \
		--eval "(package-generate-autoloads 'poly-any-jinja2 \"$(JINJA2_DIR)\")" \
		--eval "(package-generate-autoloads 'poly-ansible-jinja2 \"$(ANSIBLE_DIR)\")" \
		--eval "(package-generate-autoloads 'poly-any-go-template \"$(GO_TEMPLATE_DIR)\")" \
		--eval "(package-generate-autoloads 'poly-any-template-indent-bars \"$(INDENT_BARS_DIR)\")" \
		--eval "(package-generate-autoloads 'poly-treesit-fold \"$(TREESIT_FOLD_DIR)\")"

compile: autoloads
	$(BATCH) $(LOAD_PATH) $(PACKAGE_SETUP) \
		--eval "(setq byte-compile-error-on-warn t)" \
		-f batch-byte-compile $(SOURCES)

check-grammars:
	$(BATCH) $(PACKAGE_SETUP) \
		--eval "(require 'treesit)" \
		--eval "(dolist (language '(jinja gotmpl yaml toml)) (unless (treesit-ready-p language) (error \"The %s grammar is unavailable\" language)))"

test-jinja2: autoloads
	$(BATCH) $(LOAD_PATH) $(PACKAGE_SETUP) \
		-l poly-any-jinja2-test \
		-f ert-run-tests-batch-and-exit

test-ansible: autoloads
	$(BATCH) $(LOAD_PATH) $(PACKAGE_SETUP) \
		-l poly-ansible-jinja2-test \
		-f ert-run-tests-batch-and-exit

test-go-template: autoloads
	$(BATCH) $(LOAD_PATH) $(PACKAGE_SETUP) \
		-l yaml-ts-mode \
		-l poly-any-go-template-test \
		-f ert-run-tests-batch-and-exit

test-indent-bars: autoloads
	$(BATCH) $(LOAD_PATH) $(PACKAGE_SETUP) \
		-l poly-any-template-indent-bars-test \
		-f ert-run-tests-batch-and-exit

test-treesit-fold: autoloads
	$(BATCH) $(LOAD_PATH) $(PACKAGE_SETUP) \
		-l poly-treesit-fold-test \
		-f ert-run-tests-batch-and-exit

test: check-grammars test-jinja2 test-ansible test-go-template \
	test-indent-bars test-treesit-fold

clean:
	find . -name '*.elc' -delete
	rm -f $(AUTOLOADS)
