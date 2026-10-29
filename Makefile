SHELL := /bin/sh
PREFIX ?= $(HOME)/.local
SCRIPTS := bin/fusho lib/*.sh scripts/*.sh test/*.bats test/helpers/*.bash

.PHONY: help fmt lint test coverage check install

help:
	@echo "targets:"
	@echo "  fmt         format every script with shfmt -i 2"
	@echo "  lint        shfmt, shellcheck and mandoc at zero findings"
	@echo "  test        bats suites"
	@echo "  coverage    bashcov line coverage with a 100% gate"
	@echo "  check       lint and test"
	@echo "  install     install the tool, man page and completions under PREFIX (default ~/.local)"

fmt:
	shfmt -i 2 -w $(SCRIPTS)

lint:
	shfmt -i 2 -d $(SCRIPTS)
	shellcheck --severity=style --shell=sh -e SC3043 -x bin/fusho lib/*.sh scripts/toolset.sh scripts/check-names.sh scripts/set-version.sh
	sh scripts/check-names.sh
	shellcheck --severity=style --shell=bash scripts/coverage.sh
	shellcheck --severity=style --shell=bash completions/fusho.bash
	shellcheck --severity=style --shell=bash -e SC2154 test/*.bats test/helpers/*.bash
	mandoc -T lint man/fusho.1

test:
	bats --print-output-on-failure test

coverage:
	bash scripts/coverage.sh 100

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
