# fusho

Guidance for anyone, human or agent, changing this repository. What fusho is and how to use it lives in [README.md](README.md); this file covers how the code is built, tested and shipped.

## Family

fusho is one of four tools that share a single command-line contract: [FAMILY.md](FAMILY.md). Help page, options, prompts, output, diagnostics and `doctor` follow it. A change to the contract goes into `FAMILY.md` in all four repositories at once: fusho, kakikomi, kiyome and yakitsuke.

## Layout

| Path | Holds |
|:-----|:------|
| [`lib/`](lib) | The modules. [`build.sh`](build.sh) concatenates them, with [`lib/main.sh`](lib/main.sh) last, into `dist/fusho` |
| [`man/fusho.1`](man/fusho.1) | The man page |
| [`completions/`](completions) | bash, zsh and fish completions |
| [`test/`](test) | The `bats` suite. [`test/helpers/`](test/helpers) holds fixtures, assertions and a local key server |
| [`scripts/`](scripts) | Coverage, the coverage gate and the release version stamp |
| [`specs/`](specs) | Behaviour specs |

## Commands

| Command | Does |
|:--------|:-----|
| `make build` | Builds `dist/fusho` |
| `make fmt` | Formats with `shfmt -i 2` |
| `make lint` | ShellCheck at zero findings |
| `make test` | Builds, then runs every `bats` test |
| `make coverage` | bashcov line coverage, gated at 100% |
| `make check` | Format check, lint, test and coverage |
| `make install` | Installs the artifact, man page and completions under `~/.local` |

## Rules

- The artifact is POSIX `sh`. `local` is the one extension it relies on.
- No comments in source. Tool directives and the `Arrange`, `Act`, `Assert` markers in tests are the only exceptions.
- Tests run real `age`, `openssl` and `ssh-keygen` with generated keys. Faults come only from small wrappers placed on `PATH`.
- A new option goes into the help page, the man page and all three completions in the same commit; a test fails otherwise.
- Conventional commits, pushed straight to `main`. No pull requests.

## Release and Homebrew

- Every push to `main` runs semantic-release. A `feat` or `fix` commit publishes a release, stamps `FUSHO_VERSION` in [`lib/core.sh`](lib/core.sh) and updates the CHANGELOG.
- The Homebrew formula is not in this repository. It lives in [gufranco/homebrew-tap](https://github.com/gufranco/homebrew-tap) as `Formula/fusho.rb`, next to the formulas for the rest of the family and for other projects.
- After a release, [`.github/workflows/formula.yml`](.github/workflows/formula.yml) sends a `formula-bump` dispatch to the tap with the new tag. The tap rewrites the formula's `url` and `sha256` itself, so neither is edited by hand.
- The dispatch authenticates as a GitHub App through the `TAP_APP_ID` and `TAP_APP_PRIVATE_KEY` secrets of this repository.
- The formula's `install` block decides which files reach users. A new file that must be installed, or a new dependency, needs a matching change to `Formula/fusho.rb` in the tap.
- fusho is never published to any other package registry.
