# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  WORK="$(fixture_workspace)"
  XDG_CONFIG_HOME="${WORK}/config"
  SERVED="${WORK}/served"
  mkdir -p "${SERVED}" "${WORK}/home/.ssh" "${WORK}/outsider/.ssh"
  fixture_generate_ed25519 "${WORK}/home/.ssh" "recipient"
  fixture_generate_ed25519 "${WORK}/home/.ssh" "sender"
  fixture_generate_ed25519 "${WORK}/home/.ssh" "rotated"
  fixture_generate_ed25519 "${WORK}/outsider/.ssh" "impostor"
  fixture_publish_keys "${SERVED}" "alice" "${WORK}/home/.ssh/recipient.pub"
  fixture_publish_keys "${SERVED}" "carol" "${WORK}/home/.ssh/sender.pub"
  fixture_publish_keys "${SERVED}" "mallory" "${WORK}/outsider/.ssh/impostor.pub"
  keyserver_start "${SERVED}"
  export WORK SERVED FUSHO_GITHUB_BASE KEYSERVER_PID XDG_CONFIG_HOME
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

@test "a signed message carries the sender and the signature" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --sign carol --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "from: carol"
  assert_output_contains "sig: "
}

@test "the recipient verifies a good signature" {
  # Arrange
  "${FUSHO_BIN}" send alice 'authentic secret' --sign carol --no-clipboard >"${WORK}/signed"

  # Act
  run "${FUSHO_BIN}" read "${WORK}/signed"

  # Assert
  assert_status 0
  assert_output_contains "signature verified against a key published by 'carol'"
  assert_output_contains "authentic secret"
}

@test "a tampered body fails verification and prints no plaintext" {
  # Arrange
  "${FUSHO_BIN}" send alice 'authentic secret' --sign carol --no-clipboard >"${WORK}/tamper"
  fixture_tamper_body "${WORK}/tamper" "${WORK}/tampered"

  # Act
  run "${FUSHO_BIN}" read "${WORK}/tampered"

  # Assert
  assert_status 1
  assert_output_lacks "authentic secret"
}

@test "a signature from someone else's key is rejected" {
  # Arrange
  "${FUSHO_BIN}" send alice 'forged' --sign carol --no-clipboard >"${WORK}/forge"
  sed 's/^from: carol$/from: mallory/' "${WORK}/forge" >"${WORK}/forged"

  # Act
  run "${FUSHO_BIN}" read "${WORK}/forged"

  # Assert
  assert_status 1
  assert_output_contains "does not match any key published by 'mallory'"
  assert_output_lacks "forged"
}

@test "signing refuses when no local key matches the claimed sender" {
  # Arrange
  local expected_status=1

  # Act
  run bash -c "HOME='${WORK}/outsider' printf 'x\n' | HOME='${WORK}/outsider' '${FUSHO_BIN}' send alice --sign carol --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "no local private key matches a key published by 'carol'"
}

@test "an unsigned message is refused under --require-signature" {
  # Arrange
  "${FUSHO_BIN}" send alice 'unsigned' --no-clipboard >"${WORK}/plain"

  # Act
  run "${FUSHO_BIN}" read "${WORK}/plain" --require-signature

  # Assert
  assert_status 1
  assert_output_contains "carries no signature"
}

@test "an unsigned message still opens without --require-signature" {
  # Arrange
  "${FUSHO_BIN}" send alice 'unsigned but fine' --no-clipboard >"${WORK}/plain2"

  # Act
  run "${FUSHO_BIN}" read "${WORK}/plain2"

  # Assert
  assert_status 0
  assert_output_contains "unsigned but fine"
}

@test "the first message to someone pins their fingerprints" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "first message to 'alice'"
  assert_status 0
}

@test "a second message to the same keys is silent" {
  # Arrange
  printf 'x\n' | "${FUSHO_BIN}" send alice --no-clipboard >/dev/null 2>&1

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --no-clipboard"

  # Assert
  assert_status 0
  assert_output_lacks "first message"
}

@test "a changed key is refused with the fingerprints shown" {
  # Arrange
  printf 'x\n' | "${FUSHO_BIN}" send alice --no-clipboard >/dev/null 2>&1
  fixture_publish_keys "${SERVED}" "alice" "${WORK}/home/.ssh/rotated.pub"

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --no-clipboard"

  # Assert
  assert_status 1
  assert_output_contains "changed since you last messaged them"
  assert_output_contains "--accept-new-key"
  fixture_publish_keys "${SERVED}" "alice" "${WORK}/home/.ssh/recipient.pub"
}

@test "a changed key is accepted with --accept-new-key" {
  # Arrange
  printf 'x\n' | "${FUSHO_BIN}" send alice --no-clipboard >/dev/null 2>&1
  fixture_publish_keys "${SERVED}" "alice" "${WORK}/home/.ssh/rotated.pub"

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --accept-new-key --no-clipboard"

  # Assert
  assert_status 0
  assert_output_contains "accepted new keys for 'alice'"
  fixture_publish_keys "${SERVED}" "alice" "${WORK}/home/.ssh/recipient.pub"
}

@test "the pin store is private to the user" {
  # Arrange
  printf 'x\n' | "${FUSHO_BIN}" send alice --no-clipboard >/dev/null 2>&1

  # Act
  run ls -l "${XDG_CONFIG_HOME}/fusho/known_recipients"

  # Assert
  assert_status 0
  assert_output_contains "-rw-------"
}

@test "accepting new keys keeps the pin store private" {
  # Arrange
  printf 'x\n' | "${FUSHO_BIN}" send alice --no-clipboard >/dev/null 2>&1
  fixture_publish_keys "${SERVED}" "alice" "${WORK}/home/.ssh/rotated.pub"
  printf 'x\n' | "${FUSHO_BIN}" send alice --accept-new-key --no-clipboard >/dev/null 2>&1
  fixture_publish_keys "${SERVED}" "alice" "${WORK}/home/.ssh/recipient.pub"

  # Act
  run ls -l "${XDG_CONFIG_HOME}/fusho/known_recipients"

  # Assert
  assert_status 0
  assert_output_contains "-rw-------"
}

@test "a pin store that cannot be saved keeps the old pins and stops the send" {
  # Arrange
  printf 'x\n' | "${FUSHO_BIN}" send alice --no-clipboard >/dev/null 2>&1
  local store="${XDG_CONFIG_HOME}/fusho/known_recipients"
  local before
  before="$(cat "${store}")"
  fixture_publish_keys "${SERVED}" "alice" "${WORK}/home/.ssh/rotated.pub"
  local shims="${WORK}/shims-${BATS_TEST_NUMBER}"
  mkdir -p "${shims}"
  local real_mv
  real_mv="$(command -v mv)"
  printf '#!/bin/sh\ncase "$*" in *known_recipients) exit 1 ;; esac\nexec %s "$@"\n' "${real_mv}" >"${shims}/mv"
  chmod +x "${shims}/mv"

  # Act
  run env PATH="${shims}:${PATH}" bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --accept-new-key --no-clipboard"

  # Assert
  fixture_publish_keys "${SERVED}" "alice" "${WORK}/home/.ssh/recipient.pub"
  assert_status 1
  assert_output_contains "could not save the pinned keys for 'alice'"
  local after
  after="$(cat "${store}")"
  assert_equal "${after}" "${before}"
}
