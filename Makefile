SHELL := /bin/sh
PREFIX ?= $(HOME)/.local
SCRIPTS := bin/fusho lib/*.sh scripts/*.sh test/*.sh test/*.bash test/*.bats

.PHONY: help fmt lint test test-all coverage check install

help:
	@echo "targets:"
	@echo "  fmt         format every script with shfmt -i 2"
	@echo "  lint        shfmt, shellcheck and mandoc at zero findings"
	@echo "  test        bats suites under the system sh"
	@echo "  test-all    bats suites under every installed shell"
	@echo "  coverage    bashcov line coverage with a 100% gate"
	@echo "  check       lint and test"
	@echo "  install     install the tool, man page and completions under PREFIX (default ~/.local)"

fmt:
	shfmt -i 2 -w $(SCRIPTS)

lint:
	shfmt -i 2 -d $(SCRIPTS)
	shellcheck -x -s sh -o all bin/fusho lib/*.sh scripts/toolset.sh scripts/check-names.sh scripts/set-version.sh scripts/coverage.sh test/call.sh test/run-matrix.sh
	sh scripts/check-names.sh
	shellcheck -x -o all test/*.bash test/*.bats
	shellcheck -s bash -o all completions/fusho.bash
	mandoc -T lint man/fusho.1

test:
	FUSHO_TEST_SHELLS=sh sh test/run-matrix.sh

test-all:
	sh test/run-matrix.sh

coverage:
	sh scripts/coverage.sh 100

check: lint test

install:
	mkdir -p "$(PREFIX)/share/fusho" "$(PREFIX)/bin" "$(PREFIX)/share/man/man1" "$(PREFIX)/share/bash-completion/completions" "$(PREFIX)/share/zsh/site-functions" "$(PREFIX)/share/fish/vendor_completions.d"
	cp -R bin lib "$(PREFIX)/share/fusho/"
	cp -f man/fusho.1 "$(PREFIX)/share/man/man1/fusho.1"
	cp -f completions/fusho.bash "$(PREFIX)/share/bash-completion/completions/fusho"
	cp -f completions/_fusho "$(PREFIX)/share/zsh/site-functions/_fusho"
	cp -f completions/fusho.fish "$(PREFIX)/share/fish/vendor_completions.d/fusho.fish"
	printf '#!/bin/sh\nexec "%s/share/fusho/bin/fusho" "$$@"\n' "$(PREFIX)" > "$(PREFIX)/bin/fusho"
	chmod 755 "$(PREFIX)/bin/fusho"
