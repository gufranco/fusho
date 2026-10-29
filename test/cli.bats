# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  WORK="$(fixture_workspace)"
  XDG_CONFIG_HOME="${WORK}/config"
  SERVED="${WORK}/served"
  mkdir -p "${SERVED}" "${WORK}/home/.ssh" "${WORK}/bare/.ssh"
  fixture_generate_ed25519 "${WORK}/home/.ssh" "id_ed25519"
  fixture_publish_keys "${SERVED}" "alice" "${WORK}/home/.ssh/id_ed25519.pub"
  keyserver_start "${SERVED}"
  NOAGE="$(sandbox_path_excluding "${WORK}/bin-noage" age)"
  NOCLIP="$(sandbox_path_excluding "${WORK}/bin-noclip" none)"
  export WORK SERVED FUSHO_GITHUB_BASE KEYSERVER_PID XDG_CONFIG_HOME NOAGE NOCLIP
}

teardown_file() {
  keyserver_stop
  rm -rf "${WORK}"
}

setup() {
  export HOME="${WORK}/home"
}

@test "version reports the version and the active engine" {
  # Arrange
  local expected_status=0

  # Act
  run "${FUSHO_BIN}" version

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "fusho ${FUSHO_TEST_VERSION}"
  assert_output_contains "engine: age"
}

@test "version reports the fallback engine when age is absent" {
  # Arrange
  local expected_status=0

  # Act
  run env PATH="${NOAGE}" "${FUSHO_BIN}" version

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "rsa-oaep-sha1"
}

@test "help prints the usage block" {
  # Arrange
  local expected_status=0

  # Act
  run "${FUSHO_BIN}" help

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "fusho send <user>"
  assert_output_contains "fusho read [file]"
}

@test "no arguments without a terminal fails with a usage hint" {
  # Arrange
  local program="${FUSHO_BIN}"

  # Act
  run "${program}" </dev/null

  # Assert
  assert_status 1
  assert_equal "${output}" "fusho: no command given. run 'fusho help' for usage."
}

@test "-V prints the version like version does" {
  # Arrange
  local flag=-V

  # Act
  run "${FUSHO_BIN}" "${flag}"

  # Assert
  assert_status 0
  assert_output_contains "fusho ${FUSHO_TEST_VERSION}"
}

@test "an unknown top-level option is reported as an option" {
  # Arrange
  local option=--frobnicate

  # Act
  run "${FUSHO_BIN}" "${option}"

  # Assert
  assert_status 1
  assert_equal "${output}" "fusho: unknown option '--frobnicate'. run 'fusho help' for usage."
}

@test "an unknown command is reported" {
  # Arrange
  local expected_status=1

  # Act
  run "${FUSHO_BIN}" frobnicate

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "unknown command 'frobnicate'"
}

@test "send without a recipient and no terminal fails with a usage hint" {
  # Arrange
  local command=send

  # Act
  run "${FUSHO_BIN}" "${command}" </dev/null

  # Assert
  assert_status 1
  assert_equal "${output}" "fusho: no recipient given. run 'fusho help' for usage."
}

@test "send names an option that is missing its value" {
  # Arrange
  local option=--to

  # Act
  run "${FUSHO_BIN}" send "${option}" </dev/null

  # Assert
  assert_status 1
  assert_equal "${output}" "fusho: option '--to' needs a value. run 'fusho help' for usage."
}

@test "send accepts an option written as name=value" {
  # Arrange
  local payload
  payload="$(openssl rand -hex 8)"

  # Act
  run bash -c "printf '%s\n' '${payload}' | '${FUSHO_BIN}' send --to=alice --no-clipboard"

  # Assert
  assert_status 0
  assert_output_contains "-----BEGIN FUSHO MESSAGE-----"
}

@test "read splits an option written as name=value" {
  # Arrange
  local missing="${WORK}/no-such-message"

  # Act
  run "${FUSHO_BIN}" read --identity="${WORK}/no-such-key" "${missing}"

  # Assert
  assert_status 1
  assert_equal "${output}" "fusho: file '${missing}' does not exist."
}

@test "send rejects an unknown option" {
  # Arrange
  local option=--bogus

  # Act
  run "${FUSHO_BIN}" send alice "${option}"

  # Assert
  assert_status 1
  assert_equal "${output}" "fusho: unknown option '--bogus'. run 'fusho help' for usage."
}

@test "read rejects an unknown option" {
  # Arrange
  local option=--bogus

  # Act
  run "${FUSHO_BIN}" read "${option}"

  # Assert
  assert_status 1
  assert_equal "${output}" "fusho: unknown option '--bogus'. run 'fusho help' for usage."
}

@test "keys without a user and no terminal fails with a usage hint" {
  # Arrange
  local command=keys

  # Act
  run "${FUSHO_BIN}" "${command}" </dev/null

  # Assert
  assert_status 1
  assert_equal "${output}" "fusho: no user given. run 'fusho help' for usage."
}

@test "doctor passes when every dependency is present" {
  # Arrange
  local expected_status=0

  # Act
  run "${FUSHO_BIN}" doctor

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "age"
  assert_output_contains "ok"
}

@test "doctor fails and gives a remedy when age is missing" {
  # Arrange
  local expected_status=1

  # Act
  run env PATH="${NOAGE}" HOME="${WORK}/home" "${FUSHO_BIN}" doctor

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "missing"
  assert_output_contains "brew install age"
}

@test "doctor warns when no usable key pair exists" {
  # Arrange
  local expected_status=0

  # Act
  run env HOME="${WORK}/bare" "${FUSHO_BIN}" doctor

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "no key pair found"
}

@test "doctor counts usable identities" {
  # Arrange
  local expected_status=0

  # Act
  run "${FUSHO_BIN}" doctor

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "usable key pair"
}

@test "send still succeeds when no clipboard tool exists" {
  # Arrange
  local expected_status=0

  # Act
  run env PATH="${NOCLIP}" HOME="${WORK}/home" bash -c \
    "printf 'x\n' | '${FUSHO_BIN}' send alice"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "no clipboard tool found"
  assert_output_contains "-----BEGIN FUSHO MESSAGE-----"
}

@test "reads the message from the clipboard when nothing is piped" {
  # Arrange
  local dir="${WORK}/clipread"
  sandbox_path_excluding "${dir}" none >/dev/null
  "${FUSHO_BIN}" send alice 'clipboard sourced secret' --no-clipboard >"${WORK}/clip.armored"
  printf '%s\n' '#!/usr/bin/env bash' "cat '${WORK}/clip.armored'" >"${dir}/pbpaste"
  chmod +x "${dir}/pbpaste"

  # Act
  run env PATH="${dir}" HOME="${WORK}/home" python3 "${FUSHO_TESTS_DIR}/on_tty.py" "${FUSHO_BIN}" read

  # Assert
  assert_status 0
  assert_output_contains "clipboard sourced secret"
}

paste_shim() {
  local dir="$1" name="$2" payload="$3"
  sandbox_path_excluding "${dir}" pbpaste >/dev/null
  printf '%s\n' '#!/usr/bin/env bash' "cat '${payload}'" >"${dir}/${name}"
  chmod +x "${dir}/${name}"
}

run_read_on_tty() {
  env PATH="$1" HOME="${WORK}/home" "${FUSHO_BIN}" read --clipboard </dev/null
}

@test "reads the clipboard with wl-paste" {
  # Arrange
  "${FUSHO_BIN}" send alice 'wayland secret' --no-clipboard >"${WORK}/wl.armored"
  paste_shim "${WORK}/bin-wlpaste" wl-paste "${WORK}/wl.armored"

  # Act
  run run_read_on_tty "${WORK}/bin-wlpaste"

  # Assert
  assert_status 0
  assert_output_contains "wayland secret"
}

@test "reads the clipboard with xclip" {
  # Arrange
  "${FUSHO_BIN}" send alice 'xclip secret' --no-clipboard >"${WORK}/xc.armored"
  paste_shim "${WORK}/bin-xclippaste" xclip "${WORK}/xc.armored"

  # Act
  run run_read_on_tty "${WORK}/bin-xclippaste"

  # Assert
  assert_status 0
  assert_output_contains "xclip secret"
}

@test "reads the clipboard with xsel" {
  # Arrange
  "${FUSHO_BIN}" send alice 'xsel secret' --no-clipboard >"${WORK}/xs.armored"
  paste_shim "${WORK}/bin-xselpaste" xsel "${WORK}/xs.armored"

  # Act
  run run_read_on_tty "${WORK}/bin-xselpaste"

  # Assert
  assert_status 0
  assert_output_contains "xsel secret"
}

@test "explains what to do when there is nothing to read at all" {
  # Arrange
  local dir="${WORK}/bin-noclip-read"
  sandbox_path_excluding "${dir}" pbpaste >/dev/null

  # Act
  run run_read_on_tty "${dir}"

  # Assert
  assert_status 1
  assert_output_contains "nothing to read"
}

@test "the bash completion offers every command" {
  # Arrange
  local expected_status=0

  # Act
  run /bin/bash -c "source '${FUSHO_REPO_ROOT}/completions/fusho.bash'; COMP_WORDS=(fusho ''); COMP_CWORD=1; _fusho; printf '%s' \"\${COMPREPLY[*]}\""

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "send"
  assert_output_contains "doctor"
}

@test "the bash completion offers the send flags" {
  # Arrange
  local expected_status=0

  # Act
  run /bin/bash -c "source '${FUSHO_REPO_ROOT}/completions/fusho.bash'; COMP_WORDS=(fusho send --); COMP_CWORD=2; _fusho; printf '%s' \"\${COMPREPLY[*]}\""

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "--sign"
  assert_output_contains "--keys-file"
}

@test "the man page passes mandoc lint" {
  # Arrange
  if ! command -v mandoc >/dev/null 2>&1; then
    skip "mandoc is not installed on this machine"
  fi

  # Act
  run mandoc -T lint "${FUSHO_REPO_ROOT}/man/fusho.1"

  # Assert
  assert_status 0
}

@test "every documented flag appears in the usage text" {
  # Arrange
  local expected_status=0

  # Act
  run "${FUSHO_BIN}" help

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "--sign"
  assert_output_contains "--require-signature"
  assert_output_contains "--qr"
  assert_output_contains "--keys-file"
}

@test "fusho runs by its bare name from inside its own folder" {
  # Arrange
  local -a shell_words
  read -r -a shell_words <<<"${FUSHO_TEST_SHELL:-sh}"
  cd "${FUSHO_REPO_ROOT}/bin" || return 1

  # Act
  PATH="${FUSHO_REPO_ROOT}/bin:${PATH}" run "${shell_words[@]}" fusho version

  # Assert
  assert_status 0
  assert_output_contains "fusho ${FUSHO_TEST_VERSION}"
}

help_options() {
  local page
  page="$("${FUSHO_BIN}" help)"
  printf '%s\n' "${page}" | awk '/^  --/ { for (i = 1; i <= NF; i++) if (match($i, /^--[a-z0-9][a-z0-9-]*/)) { option = substr($i, RSTART, RLENGTH); if (!seen[option]++) print option } }'
}

option_drift() {
  local root="${FUSHO_REPO_ROOT}" option name man_form missing="" listed completed
  listed="$(help_options)"
  completed="$(grep -oE -- "--[a-z0-9][a-z0-9-]*" "${root}/completions/fusho.bash")"
  for option in ${listed}; do
    name="${option#--}"
    man_form="\\-\\-${name//-/\\-}"
    grep -qF -- "${man_form}" "${root}/man/fusho.1" || missing="${missing} man:${option}"
    grep -qE -- "(^|[ \"])${option}( |\"|$)" "${root}/completions/fusho.bash" || missing="${missing} bash:${option}"
    grep -qE -- "'\\*?${option}\\[" "${root}/completions/_fusho" || missing="${missing} zsh:${option}"
    grep -qE -- "-l ${name} " "${root}/completions/fusho.fish" || missing="${missing} fish:${option}"
  done
  while IFS= read -r option; do
    printf '%s\n' "${listed}" | grep -qx -- "${option}" || missing="${missing} help:${option}"
  done <<<"${completed}"
  printf '%s' "${missing}"
}

@test "the help page, man page and completions list the same options" {
  # Arrange
  local expected=""

  # Act
  run option_drift

  # Assert
  assert_status 0
  assert_equal "${output}" "${expected}"
}
