EMACS ?= emacs
BATCH = $(EMACS) -Q --batch
JINJA2_TS_MODE_PATH ?= ../jinja2-ts-mode
LOAD_PATH = -L . -L test -L $(JINJA2_TS_MODE_PATH)
GO_TEMPLATE_URL = https://github.com/chuxubank/go-template-ts-mode
JINJA2_TS_MODE_URL = https://github.com/chuxubank/jinja2-ts-mode

SOURCES = poly-any-template.el poly-any-jinja2.el poly-any-go-template.el \
	poly-treesit-fold.el

PACKAGE_SETUP = \
	--eval "(require 'package)" \
	--eval "(package-initialize)" \
	--eval "(setq load-prefer-newer t)" \
	--eval "(when (file-directory-p \"$(JINJA2_TS_MODE_PATH)/.tree-sitter\") (add-to-list 'treesit-extra-load-path \"$(JINJA2_TS_MODE_PATH)/.tree-sitter\"))" \
	--eval "(setq load-path (cons \"$(CURDIR)\" (delete \"$(CURDIR)\" load-path)))" \
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
