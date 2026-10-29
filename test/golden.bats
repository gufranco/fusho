#!/usr/bin/env bats

# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  WORK="$(fixture_workspace)"
  SERVED="${WORK}/served"
  mkdir -p "${SERVED}" "${WORK}/home/.ssh"
  fixture_generate_ed25519 "${WORK}/home/.ssh" "recipient"
  fixture_generate_ed25519 "${WORK}/home/.ssh" "sender"
  fixture_publish_keys "${SERVED}" "alice" "${WORK}/home/.ssh/recipient.pub"
  fixture_publish_keys "${SERVED}" "carol" "${WORK}/home/.ssh/sender.pub"
  keyserver_start "${SERVED}"
  export WORK SERVED FUSHO_GITHUB_BASE KEYSERVER_PID
}

teardown_file() {
  keyserver_stop
  rm -rf "${WORK}"
}

setup() {
  export HOME="${WORK}/home"
  # shellcheck disable=SC2154
  export XDG_CONFIG_HOME="${WORK}/config-${BATS_TEST_NUMBER}"
  mkdir -p "${XDG_CONFIG_HOME}"
}

@test "a first signed send prints the same transcript as the recorded one" {
  # Arrange
  local message='meet at noon'

  # Act
  run "${FUSHO_BIN}" send alice "${message}" --sign carol --no-clipboard --no-banner

  # Assert
  assert_status 0
  fusho_test_matches_golden send "${output}"
}

@test "reading a signed message prints the same transcript as the recorded one" {
  # Arrange
  "${FUSHO_BIN}" send alice 'meet at noon' --sign carol --no-clipboard >"${WORK}/signed" 2>/dev/null

  # Act
  run "${FUSHO_BIN}" read "${WORK}/signed"

  # Assert
  assert_status 0
  fusho_test_matches_golden read "${output}"
}
