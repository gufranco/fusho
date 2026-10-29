# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  WORK="$(fixture_workspace)"
  XDG_CONFIG_HOME="${WORK}/config"
  SERVED="${WORK}/served"
  mkdir -p "${SERVED}" "${WORK}/home/.ssh"
  fixture_generate_ed25519 "${WORK}/home/.ssh" "id_ed25519"
  fixture_publish_keys "${SERVED}" "alice" "${WORK}/home/.ssh/id_ed25519.pub"
  keyserver_start "${SERVED}"
  export WORK SERVED FUSHO_GITHUB_BASE KEYSERVER_PID XDG_CONFIG_HOME
}

teardown_file() {
  keyserver_stop
  rm -rf "${WORK}"
}

setup() {
  export HOME="${WORK}/home"
}

round_trip_under() {
  local runner="$1" dir="$2"
  printf 'portable payload\n' >"${dir}/original"
  ${runner} "${FUSHO_REPO_ROOT}/bin/fusho" send alice --no-clipboard <"${dir}/original" >"${dir}/armored"
  ${runner} "${FUSHO_REPO_ROOT}/bin/fusho" read "${dir}/armored" >"${dir}/recovered"
  cmp -s "${dir}/original" "${dir}/recovered"
}

@test "the entry point declares a POSIX sh shebang" {
  # Arrange
  local expected_status=0

  # Act
  run head -1 "${FUSHO_REPO_ROOT}/bin/fusho"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "/bin/sh"
}

@test "the entry point and modules contain no bash-only constructs" {
  # Arrange
  local expected_status=1

  # Act
  run grep -nE '\[\[|<\(|pipefail|BASH_SOURCE|\bdeclare\b|\bmapfile\b|\breadarray\b' "${FUSHO_REPO_ROOT}/bin/fusho" "${FUSHO_REPO_ROOT}"/lib/*.sh

  # Assert
  assert_status "${expected_status}"
}

@test "round trips under the system sh" {
  # Arrange
  local dir="${WORK}/sh"
  mkdir -p "${dir}"

  # Act
  run round_trip_under /bin/sh "${dir}"

  # Assert
  assert_status 0
}

@test "round trips under the system bash" {
  # Arrange
  local dir="${WORK}/bash"
  mkdir -p "${dir}"

  # Act
  run round_trip_under /bin/bash "${dir}"

  # Assert
  assert_status 0
}

@test "round trips under the system zsh" {
  # Arrange
  local dir="${WORK}/zsh"
  mkdir -p "${dir}"
  [[ -x /bin/zsh ]] || skip "this system ships no zsh"

  # Act
  run round_trip_under /bin/zsh "${dir}"

  # Assert
  assert_status 0
}

round_trip_each() {
  local shell dir
  for shell in "$@"; do
    dir="${WORK}/each-${shell//[^A-Za-z0-9]/_}"
    mkdir -p "${dir}"
    round_trip_under "${shell}" "${dir}" || return 1
  done
}

@test "round trips under Homebrew's bash and zsh on macOS" {
  # Arrange
  [[ "$(uname -s || true)" == Darwin ]] || skip "only macOS ships an older bash and zsh next to Homebrew's"
  local brew_bin
  brew_bin="$(brew --prefix)/bin"

  # Act
  run round_trip_each "${brew_bin}/bash" "${brew_bin}/zsh"

  # Assert
  assert_status 0
}

@test "round trips under every other shell present on this machine" {
  # Arrange
  local -a shells=()
  local candidate
  for candidate in dash ash ksh mksh oksh posh yash zsh; do
    if command -v "${candidate}" >/dev/null 2>&1; then
      shells+=("${candidate}")
    fi
  done
  if command -v busybox >/dev/null 2>&1; then
    shells+=("busybox sh")
  fi

  # Act
  run round_trip_each "${shells[@]}"

  # Assert
  assert_status 0
}

@test "survives a TMPDIR containing spaces" {
  # Arrange
  local dir="${WORK}/tmp dir with spaces"
  mkdir -p "${dir}"

  # Act
  TMPDIR="${dir}" run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --no-clipboard"

  # Assert
  assert_status 0
  assert_output_contains "-----BEGIN FUSHO MESSAGE-----"
}

@test "survives a HOME containing spaces" {
  # Arrange
  local spaced="${WORK}/home with spaces"
  mkdir -p "${spaced}/.ssh"
  cp -f "${WORK}/home/.ssh/id_ed25519" "${WORK}/home/.ssh/id_ed25519.pub" "${spaced}/.ssh/"
  "${FUSHO_BIN}" send alice 'spaced home secret' --no-clipboard >"${WORK}/spaced.armored"

  # Act
  HOME="${spaced}" run "${FUSHO_BIN}" read "${WORK}/spaced.armored"

  # Assert
  assert_status 0
  assert_output_contains "spaced home secret"
}

@test "survives a hostile IFS" {
  # Arrange
  local expected_status=0

  # Act
  run env IFS=':' HOME="${WORK}/home" bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "-----BEGIN FUSHO MESSAGE-----"
}

@test "survives CDPATH being set" {
  # Arrange
  local expected_status=0

  # Act
  run env CDPATH=/usr HOME="${WORK}/home" bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "-----BEGIN FUSHO MESSAGE-----"
}

@test "survives POSIXLY_CORRECT" {
  # Arrange
  local expected_status=0

  # Act
  run env POSIXLY_CORRECT=1 HOME="${WORK}/home" bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "-----BEGIN FUSHO MESSAGE-----"
}

@test "carries non-ASCII intact under the C locale" {
  # Arrange
  printf 'acentua\303\247\303\243o \303\247edilha\n' >"${WORK}/utf8"
  env LC_ALL=C LANG=C "${FUSHO_BIN}" send alice --no-clipboard <"${WORK}/utf8" >"${WORK}/utf8.armored"

  # Act
  env LC_ALL=C LANG=C "${FUSHO_BIN}" read "${WORK}/utf8.armored" >"${WORK}/utf8.recovered"

  # Assert
  assert_files_identical "${WORK}/utf8" "${WORK}/utf8.recovered"
}

@test "carries non-ASCII intact under a UTF-8 locale" {
  # Arrange
  printf 'acentua\303\247\303\243o \303\247edilha\n' >"${WORK}/utf8b"
  env LC_ALL=en_US.UTF-8 "${FUSHO_BIN}" send alice --no-clipboard <"${WORK}/utf8b" >"${WORK}/utf8b.armored"

  # Act
  env LC_ALL=en_US.UTF-8 "${FUSHO_BIN}" read "${WORK}/utf8b.armored" >"${WORK}/utf8b.recovered"

  # Assert
  assert_files_identical "${WORK}/utf8b" "${WORK}/utf8b.recovered"
}

@test "creates private temporary files under a permissive umask" {
  # Arrange
  local expected_status=0

  # Act
  run env HOME="${WORK}/home" bash -c "umask 000; printf 'x\n' | '${FUSHO_BIN}' send alice --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "-----BEGIN FUSHO MESSAGE-----"
}

@test "works under a restrictive umask" {
  # Arrange
  local expected_status=0

  # Act
  run env HOME="${WORK}/home" bash -c "umask 077; printf 'x\n' | '${FUSHO_BIN}' send alice --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "-----BEGIN FUSHO MESSAGE-----"
}

@test "carries a payload with no trailing newline" {
  # Arrange
  printf 'no trailing newline' >"${WORK}/bare"
  "${FUSHO_BIN}" send alice --no-clipboard <"${WORK}/bare" >"${WORK}/bare.armored"

  # Act
  "${FUSHO_BIN}" read "${WORK}/bare.armored" >"${WORK}/bare.recovered"

  # Assert
  assert_files_identical "${WORK}/bare" "${WORK}/bare.recovered"
}

@test "carries binary content without corruption" {
  # Arrange
  head -c 4096 /dev/urandom >"${WORK}/binary"
  "${FUSHO_BIN}" send alice --no-clipboard <"${WORK}/binary" >"${WORK}/binary.armored"

  # Act
  "${FUSHO_BIN}" read "${WORK}/binary.armored" >"${WORK}/binary.recovered"

  # Assert
  assert_files_identical "${WORK}/binary" "${WORK}/binary.recovered"
}

@test "reads an armored block surrounded by unrelated chat text" {
  # Arrange
  "${FUSHO_BIN}" send alice 'buried secret' --no-clipboard >"${WORK}/core.armored"
  {
    printf 'hey, here is the thing you asked for\n\n'
    cat "${WORK}/core.armored"
    printf '\nlet me know if it works\n'
  } >"${WORK}/chatty"

  # Act
  run "${FUSHO_BIN}" read "${WORK}/chatty"

  # Assert
  assert_status 0
  assert_output_contains "buried secret"
}

@test "tolerates CRLF line endings from a chat client" {
  # Arrange
  "${FUSHO_BIN}" send alice 'crlf secret' --no-clipboard >"${WORK}/lf.armored"
  awk '{printf "%s\r\n", $0}' "${WORK}/lf.armored" >"${WORK}/crlf.armored"

  # Act
  run "${FUSHO_BIN}" read "${WORK}/crlf.armored"

  # Assert
  assert_status 0
  assert_output_contains "crlf secret"
}
