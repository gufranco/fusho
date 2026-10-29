# Changelog

# [3.0.0](https://github.com/gufranco/fusho/compare/v2.4.0...v3.0.0) (2026-10-29)


* feat!: drop -v as a spelling of version ([ce9e661](https://github.com/gufranco/fusho/commit/ce9e6618ad2c268326f438629598f7adfe617507))
* feat!: run fusho from bin/ and lib/ ([c000158](https://github.com/gufranco/fusho/commit/c000158a382f860850a4c4dcb06a19100eaa2ba7))


### Bug Fixes

* escape control characters in JSON output ([d13adf8](https://github.com/gufranco/fusho/commit/d13adf8ef8e2b21fad35cb55787b569338053c76))
* pin keys through one private atomic write ([6889181](https://github.com/gufranco/fusho/commit/6889181d71524b7a15f6099b4f17a3d9c06e637d))
* refuse a message body that is not base64 ([b31709b](https://github.com/gufranco/fusho/commit/b31709bcb26648a7cdd1d16f2d438a055455e344))


### Features

* run fusho on any POSIX sh, ksh93 included ([685987e](https://github.com/gufranco/fusho/commit/685987e7f885218c44e12bc7fe61a44290f42438))


### BREAKING CHANGES

* fusho -v no longer prints the version; use fusho -V,
fusho --version or fusho version.
* releases no longer attach the single-file dist/fusho.
Install fusho with Homebrew or make install from a checkout.

# [2.4.0](https://github.com/gufranco/fusho/compare/v2.3.0...v2.4.0) (2026-10-29)


### Features

* fit terminal output in 80 columns ([168ebc9](https://github.com/gufranco/fusho/commit/168ebc91392427ec0b7784f2a02a19828fe9469c))

# [2.3.0](https://github.com/gufranco/fusho/compare/v2.2.0...v2.3.0) (2026-10-27)


### Features

* **doctor:** name the flavor of each core tool ([5ab6ba1](https://github.com/gufranco/fusho/commit/5ab6ba1d0738467a94429ec56ff93d6e93f6e9e0))

# [2.2.0](https://github.com/gufranco/fusho/compare/v2.1.0...v2.2.0) (2026-10-27)


### Features

* **cli:** follow the family command-line contract ([51aef7c](https://github.com/gufranco/fusho/commit/51aef7c7069abd0e7e2389f78e5326edfef2d981))

# [2.1.0](https://github.com/gufranco/fusho/compare/v2.0.0...v2.1.0) (2026-10-26)


### Bug Fixes

* **core:** report a shell without local under set -u ([d713dc1](https://github.com/gufranco/fusho/commit/d713dc1c9cc65df4602b2e613508588ba79ba111))


### Features

* **cli:** ask for missing values in a terminal ([8f234e9](https://github.com/gufranco/fusho/commit/8f234e9751044141efc560dd2aa7a95442c88951))

# [2.0.0](https://github.com/gufranco/fusho/compare/v1.8.0...v2.0.0) (2026-10-25)


* feat!: rename osm to fusho ([de2d2ae](https://github.com/gufranco/fusho/commit/de2d2ae4ed788e46770b212a1f63bf297137eb4d))


### BREAKING CHANGES

* the command is fusho, environment variables use the
FUSHO_ prefix, and new messages begin with BEGIN FUSHO MESSAGE.

# [1.8.0](https://github.com/gufranco/fusho/compare/v1.7.0...v1.8.0) (2026-08-12)


### Features

* handle keys that live in an ssh agent ([8ac109c](https://github.com/gufranco/fusho/commit/8ac109c128b7b650d8eef9d2e856075f2ac4547f))

# [1.7.0](https://github.com/gufranco/fusho/compare/v1.6.0...v1.7.0) (2026-08-12)


### Bug Fixes

* bump the formula inside the release job ([5f83a9b](https://github.com/gufranco/fusho/commit/5f83a9bdc2e5298e22379bb042a2c6e2bb3d7cdc))


### Features

* tell a first-time recipient what the block is ([9c5d80c](https://github.com/gufranco/fusho/commit/9c5d80ce262798157d79e174c1cc23ece398b844))

# [1.6.0](https://github.com/gufranco/fusho/compare/v1.5.0...v1.6.0) (2026-08-12)


### Features

* make this repo its own homebrew tap ([0b2279f](https://github.com/gufranco/fusho/commit/0b2279f8e134e24c2d23f33e3af0eb99099bde91))

# [1.5.0](https://github.com/gufranco/fusho/compare/v1.4.0...v1.5.0) (2026-08-12)


### Bug Fixes

* probe the terminal without killing the shell ([505a280](https://github.com/gufranco/fusho/commit/505a2808cc2d5badeb480153e4a33aed5ced6c11))


### Features

* expiry, clipboard overrides and clearer failures ([e4f0ef9](https://github.com/gufranco/fusho/commit/e4f0ef964ec5e4cccd8c2f799363bec717884623))

# [1.4.0](https://github.com/gufranco/fusho/compare/v1.3.0...v1.4.0) (2026-08-12)


### Bug Fixes

* keep the bash completion working on bash 3.2 ([8957f9c](https://github.com/gufranco/fusho/commit/8957f9c8c0a023259b7e0b2681fee6b86bdb9251))


### Features

* ship a man page, shell completions and a formula ([a25c297](https://github.com/gufranco/fusho/commit/a25c297757a24f4dad9917af135d1b5ebd8f211d))

# [1.3.0](https://github.com/gufranco/fusho/compare/v1.2.0...v1.3.0) (2026-08-12)


### Features

* compress payloads, flag weak keys, expire the clipboard ([13cab1e](https://github.com/gufranco/fusho/commit/13cab1e061a46417693a9ce427d348fe8667a2c2))

# [1.2.0](https://github.com/gufranco/fusho/compare/v1.1.0...v1.2.0) (2026-08-12)


### Features

* sign messages and pin recipient keys ([d9c6197](https://github.com/gufranco/fusho/commit/d9c6197ff3abf669d7e7d6e12482f9bbae5865c9))

# [1.1.0](https://github.com/gufranco/fusho/compare/v1.0.0...v1.1.0) (2026-08-12)


### Features

* reach recipients beyond GitHub, and several at once ([ff35eec](https://github.com/gufranco/fusho/commit/ff35eecbd82683c9b0af0d73392983e959f86344))

# 1.0.0 (2026-08-12)


### Bug Fixes

* make the artifact run on any POSIX shell ([f39872d](https://github.com/gufranco/fusho/commit/f39872d24fb285cc07bdf05ccc15e1ed0cb1deb6))


### Features

* add fusho, encrypted messages over any chat ([1baca30](https://github.com/gufranco/fusho/commit/1baca305ff0b30abfafa958f7a57b9d5215cb35c))
