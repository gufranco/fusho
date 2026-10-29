# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  WORK="$(fixture_workspace)"
  XDG_CONFIG_HOME="${WORK}/config"
  SERVED="${WORK}/served"
  mkdir -p "${SERVED}" "${WORK}/home/.ssh" "${WORK}/scratch"
  fixture_generate_ed25519 "${WORK}/home/.ssh" "id_ed25519"
  fixture_publish_keys "${SERVED}" "alice" "${WORK}/home/.ssh/id_ed25519.pub"
  keyserver_start "${SERVED}"
  FAKEBIN="$(sandbox_path_excluding "${WORK}/bin-fake" none)"
  printf '#!/usr/bin/env bash\ncat >"%s/clipboard"\n' "${WORK}" >"${FAKEBIN}/pbcopy"
  chmod +x "${FAKEBIN}/pbcopy"
  export WORK SERVED FUSHO_GITHUB_BASE KEYSERVER_PID XDG_CONFIG_HOME FAKEBIN
}

teardown_file() {
  keyserver_stop
  rm -rf "${WORK}"
}

setup() {
  export HOME="${WORK}/home"
  rm -rf "${WORK}/scratch"
  mkdir -p "${WORK}/scratch"
}

@test "removes its workspace after a successful run" {
  # Arrange
  local expected_status=0

  # Act
  TMPDIR="${WORK}/scratch" run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_equal "$(find "${WORK}/scratch" -maxdepth 1 -name 'fusho-*' -print || true)" ""
}

@test "removes its workspace after a failed run" {
  # Arrange
  local expected_status=1

  # Act
  TMPDIR="${WORK}/scratch" run bash -c "printf 'x\n' | '${FUSHO_BIN}' send ghost --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_equal "$(find "${WORK}/scratch" -maxdepth 1 -name 'fusho-*' -print || true)" ""
}

@test "removes its workspace after decrypting" {
  # Arrange
  "${FUSHO_BIN}" send alice 'cleanup check' --no-clipboard >"${WORK}/msg"

  # Act
  TMPDIR="${WORK}/scratch" run "${FUSHO_BIN}" read "${WORK}/msg"

  # Assert
  assert_status 0
  assert_equal "$(find "${WORK}/scratch" -maxdepth 1 -name 'fusho-*' -print || true)" ""
}

@test "copies only ciphertext to the clipboard" {
  # Arrange
  local payload="clipboard-canary-${RANDOM}"

  # Act
  run env PATH="${FAKEBIN}" HOME="${WORK}/home" bash -c \
    "printf '%s\n' '${payload}' | '${FUSHO_BIN}' send alice"

  # Assert
  assert_status 0
  assert_output_contains "copied to the clipboard with pbcopy"
  run cat "${WORK}/clipboard"
  assert_output_contains "-----BEGIN FUSHO MESSAGE-----"
  assert_output_lacks "${payload}"
}

@test "documents that stdin avoids exposing the message in the process list" {
  # Arrange
  local expected_status=0

  # Act
  run "${FUSHO_BIN}" help

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "process list"
}
