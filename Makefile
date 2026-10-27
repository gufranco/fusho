SHELL := /bin/bash
ARTIFACT := dist/fusho
SOURCES := lib build.sh install.sh scripts/coverage.sh scripts/set-version.sh scripts/toolset.sh
TESTS := test
COVERAGE_DIR := coverage
COVERAGE_MIN := 100

.PHONY: help build fmt fmt-check lint test coverage check clean install

help:
	@echo "targets:"
	@echo "  build      concatenate lib/*.sh into $(ARTIFACT)"
	@echo "  fmt        format shell sources with shfmt"
	@echo "  fmt-check  fail when formatting is not applied"
	@echo "  lint       shellcheck at zero warnings"
	@echo "  test       build, then run the bats suite"
	@echo "  coverage   bashcov line coverage with a $(COVERAGE_MIN)% gate"
	@echo "  check      fmt-check, lint, test, coverage"
	@echo "  install    install $(ARTIFACT), the man page and the completions"

build:
	@bash build.sh

fmt:
	shfmt -w -i 2 $(SOURCES) $(TESTS)

fmt-check:
	shfmt -d -i 2 $(SOURCES) $(TESTS)

lint: build
	shellcheck --severity=style --shell=sh -e SC3043 $(ARTIFACT)
	shellcheck --severity=style --shell=bash build.sh install.sh scripts/coverage.sh scripts/set-version.sh
	shellcheck --severity=style --shell=sh scripts/toolset.sh
	shellcheck --severity=style --shell=bash completions/fusho.bash
	shellcheck --severity=style --shell=bash -e SC2154 $(TESTS)/*.bats $(TESTS)/helpers/*.bash

test: build
	bats --print-output-on-failure $(TESTS)

coverage: build
	@bash scripts/coverage.sh $(COVERAGE_MIN)

check: fmt-check lint test coverage

clean:
	rm -rf $(COVERAGE_DIR) dist $(TESTS)/tmp

install: build
	@bash install.sh
