EMACS ?= emacs
BATCH = $(EMACS) -Q --batch
JINJA2_TS_MODE_PATH ?= ../jinja2-ts-mode
SHARED_DIR = lisp/shared
JINJA2_DIR = lisp/jinja2
GO_TEMPLATE_DIR = lisp/go-template
TREESIT_FOLD_DIR = lisp/treesit-fold
LOAD_PATH = -L $(SHARED_DIR) -L $(JINJA2_DIR) -L $(GO_TEMPLATE_DIR) \
	-L $(TREESIT_FOLD_DIR) -L test -L $(JINJA2_TS_MODE_PATH)
GO_TEMPLATE_URL = https://github.com/chuxubank/go-template-ts-mode
JINJA2_TS_MODE_URL = https://github.com/chuxubank/jinja2-ts-mode

SOURCES = $(SHARED_DIR)/poly-any-template.el \
	$(JINJA2_DIR)/poly-any-jinja2.el \
	$(GO_TEMPLATE_DIR)/poly-any-go-template.el \
	$(TREESIT_FOLD_DIR)/poly-treesit-fold.el

PACKAGE_SETUP = \
	--eval "(require 'package)" \
	--eval "(package-initialize)" \
	--eval "(setq load-prefer-newer t)" \
	--eval "(when (file-directory-p \"$(JINJA2_TS_MODE_PATH)/.tree-sitter\") (add-to-list 'treesit-extra-load-path \"$(JINJA2_TS_MODE_PATH)/.tree-sitter\"))" \
	--eval "(dolist (directory '(\"$(CURDIR)/$(SHARED_DIR)\" \"$(CURDIR)/$(JINJA2_DIR)\" \"$(CURDIR)/$(GO_TEMPLATE_DIR)\" \"$(CURDIR)/$(TREESIT_FOLD_DIR)\")) (setq load-path (cons directory (delete directory load-path))))" \
	--eval "(setq load-path (cons \"$(CURDIR)/test\" (delete \"$(CURDIR)/test\" load-path)))"

ARCHIVES = \
	--eval "(require 'package)" \
	--eval "(add-to-list 'package-archives '(\"melpa\" . \"https://melpa.org/packages/\") t)" \
	--eval "(add-to-list 'package-archives '(\"jcs-elpa\" . \"https://jcs-emacs.github.io/jcs-elpa/packages/\") t)" \
	--eval "(package-initialize)"

.PHONY: all install-deps compile test test-jinja2 test-go-template \
	test-treesit-fold clean

all: compile test

install-deps:
	$(BATCH) $(ARCHIVES) \
		--eval "(package-refresh-contents)" \
		--eval "(package-install 'polymode)" \
		--eval "(package-install 'indent-bars)" \
		--eval "(package-install 'treesit-fold)" \
		--eval "(unless (package-installed-p 'go-template-ts-mode) (package-vc-install \"$(GO_TEMPLATE_URL)\"))" \
		--eval "(unless (package-installed-p 'jinja2-ts-mode) (package-vc-install \"$(JINJA2_TS_MODE_URL)\"))" \
		--eval "(require 'jinja2-ts-mode)" \
		--eval "(unless (treesit-language-available-p 'jinja) (jinja2-ts-mode-install-grammar))"

compile:
	$(BATCH) $(LOAD_PATH) $(PACKAGE_SETUP) \
		--eval "(setq byte-compile-error-on-warn t)" \
		-f batch-byte-compile $(SOURCES)

test-jinja2:
	$(BATCH) $(LOAD_PATH) $(PACKAGE_SETUP) \
		-l poly-any-jinja2-test \
		-f ert-run-tests-batch-and-exit

test-go-template:
	$(BATCH) $(LOAD_PATH) $(PACKAGE_SETUP) \
		-l yaml-ts-mode \
		-l poly-any-go-template-test \
		-f ert-run-tests-batch-and-exit

test-treesit-fold:
	$(BATCH) $(LOAD_PATH) $(PACKAGE_SETUP) \
		-l poly-treesit-fold-test \
		-f ert-run-tests-batch-and-exit

test: test-jinja2 test-go-template test-treesit-fold

clean:
	find . -name '*.elc' -delete
