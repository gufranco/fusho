# fusho

Guidance for anyone, human or agent, changing fusho. What fusho is and how to use it lives in [README.md](README.md).

[FAMILY.md](FAMILY.md) holds everything fusho shares with the rest of the kodougu family, and it is the same in every member. This file holds only what is exclusive to fusho, under the same headings as the agent guide of every member. Read both before changing anything; a rule that would serve the other members goes into `FAMILY.md` instead of here.

## Layout

| Path | Holds |
|:-----|:------|
| [`bin/fusho`](bin/fusho) | The entry point: it sources the modules, sets the traps and dispatches the command |
| [`lib/`](lib) | The modules. [`lib/state.sh`](lib/state.sh) declares every global except the version, which lives in [`lib/core.sh`](lib/core.sh) |
| [`man/fusho.1`](man/fusho.1) | The man page |
| [`completions/`](completions) | bash, zsh and fish completions |
| [`test/`](test) | The `bats` suite, its helpers, the shell matrix runner, a local key server and a terminal shim |
| [`scripts/`](scripts) | Coverage, the coverage gate, the name check, the toolset helper and the release version stamp |
| [`specs/`](specs) | Behaviour specs |

## Names

- Globals carry `FUSHO_` and are assigned outright, never read from the environment; function-scoped variables carry a per-function prefix, such as `fusho_cs_` in `fusho_cmd_send`.
- Settings come from `FUSHO_<NAME>`, including its tuning values; test switches are `FUSHO_TERMINAL` and `FUSHO_TEST_SHELLS`.
- Output goes through `fusho_say`, `fusho_die` and `fusho_warn`.

## Behaviour

- fusho has several jobs, so a bare `fusho` on a terminal opens the menu.
- `fusho send --json` prints the sent message as one JSON object.

## Domain rules

- Tests run the real `age`, `openssl` and `ssh-keygen` with generated keys, against the local key server in [`test/keyserver.py`](test/keyserver.py).
- A message body is checked as base64 before it is decoded, because `openssl base64 -d` does not fail on bad input.
- CI also runs fusho under musl and busybox, and checks that messages round-trip between platforms.

## Release

- `FUSHO_VERSION` lives in [`lib/core.sh`](lib/core.sh).
- The tap's `Formula/fusho.rb` depends on `age`.

## Gaps against FAMILY.md

As of 2026-10-29, closed in the change that removes each line:

- No `make test-linux`, `test/linux-container.sh` or merged local coverage.
- No golden transcripts.
- The pinned-key store in [`lib/trust.sh`](lib/trust.sh) is appended to and truncated in place, not rewritten through a temporary file.
