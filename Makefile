EMACS ?= emacs
BATCH = $(EMACS) -Q --batch
LOAD_PATH = -L . -L test
GO_TEMPLATE_URL = https://github.com/chuxubank/go-template-ts-mode

SOURCES = poly-any-template.el poly-any-jinja2.el poly-any-go-template.el \
	poly-treesit-fold.el

PACKAGE_SETUP = \
	--eval "(require 'package)" \
	--eval "(package-initialize)" \
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
		--eval "(package-install 'jinja2-mode)" \
		--eval "(package-install 'treesit-fold)" \
		--eval "(unless (package-installed-p 'go-template-ts-mode) (package-vc-install \"$(GO_TEMPLATE_URL)\"))"

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
