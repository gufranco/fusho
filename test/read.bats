# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  WORK="$(fixture_workspace)"
  XDG_CONFIG_HOME="${WORK}/config"
  SERVED="${WORK}/served"
  mkdir -p "${SERVED}" "${WORK}/home/.ssh" "${WORK}/stranger/.ssh"
  fixture_generate_ed25519 "${WORK}/home/.ssh" "id_ed25519_personal"
  fixture_generate_ed25519 "${WORK}/stranger/.ssh" "id_ed25519"
  fixture_publish_keys "${SERVED}" "alice" "${WORK}/home/.ssh/id_ed25519_personal.pub"
  keyserver_start "${SERVED}"
  ADDRESSED="$(fixture_fingerprint "${WORK}/home/.ssh/id_ed25519_personal.pub")"
  HOME="${WORK}/home" "${FUSHO_BIN}" send alice 'the recovered secret' --no-clipboard >"${WORK}/message"
  export WORK SERVED FUSHO_GITHUB_BASE KEYSERVER_PID XDG_CONFIG_HOME ADDRESSED
}

teardown_file() {
  keyserver_stop
  rm -rf "${WORK}"
}

setup() {
  export HOME="${WORK}/home"
}

@test "finds the matching identity under a non-default filename" {
  # Arrange
  local expected_status=0

  # Act
  run "${FUSHO_BIN}" read "${WORK}/message"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "the recovered secret"
}

@test "reads the message from stdin" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "'${FUSHO_BIN}' read < '${WORK}/message'"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "the recovered secret"
}

@test "names the addressed fingerprint when no local key matches" {
  # Arrange
  local expected_status=1

  # Act
  HOME="${WORK}/stranger" run "${FUSHO_BIN}" read "${WORK}/message"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "no local private key matches"
  assert_output_contains "${ADDRESSED}"
}

@test "rejects a message whose body was altered" {
  # Arrange
  fixture_tamper_body "${WORK}/message" "${WORK}/tampered"

  # Act
  run "${FUSHO_BIN}" read "${WORK}/tampered"

  # Assert
  assert_status 1
  assert_output_lacks "the recovered secret"
}

@test "reports a truncated message missing its closing line" {
  # Arrange
  grep -v -- "-----END FUSHO MESSAGE-----" "${WORK}/message" >"${WORK}/truncated"

  # Act
  run "${FUSHO_BIN}" read "${WORK}/truncated"

  # Assert
  assert_status 1
  assert_output_contains "truncated"
}

@test "reports input that is not an fusho message at all" {
  # Arrange
  printf 'just some chat text\n' >"${WORK}/noise"

  # Act
  run "${FUSHO_BIN}" read "${WORK}/noise"

  # Assert
  assert_status 1
  assert_output_contains "no fusho message found"
}

@test "reports a body that is not valid base64" {
  # Arrange
  fixture_corrupt_body "${WORK}/message" "${WORK}/corrupt"

  # Act
  run "${FUSHO_BIN}" read "${WORK}/corrupt"

  # Assert
  assert_status 1
  assert_output_contains "the message body is not valid base64"
  assert_output_lacks "the recovered secret"
}

@test "reports a message with no key header" {
  # Arrange
  grep -v '^key: ' "${WORK}/message" >"${WORK}/nokey"

  # Act
  run "${FUSHO_BIN}" read "${WORK}/nokey"

  # Assert
  assert_status 1
  assert_output_contains "no key header"
}

@test "reports an algorithm it does not understand" {
  # Arrange
  sed 's/^alg: age$/alg: future-cipher/' "${WORK}/message" >"${WORK}/future"

  # Act
  run "${FUSHO_BIN}" read "${WORK}/future"

  # Assert
  assert_status 1
  assert_output_contains "unknown algorithm"
}

@test "honours an explicit identity override" {
  # Arrange
  local expected_status=0

  # Act
  run "${FUSHO_BIN}" read --identity "${WORK}/home/.ssh/id_ed25519_personal" "${WORK}/message"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "the recovered secret"
}

@test "reports an identity override that does not exist" {
  # Arrange
  local expected_status=1

  # Act
  run "${FUSHO_BIN}" read --identity "${WORK}/nope" "${WORK}/message"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "does not exist"
}

@test "reports a missing input file" {
  # Arrange
  local expected_status=1

  # Act
  run "${FUSHO_BIN}" read "${WORK}/absent-file"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "does not exist"
}

@test "recognises a key held only by the ssh agent" {
  # Arrange
  if ! command -v ssh-agent >/dev/null 2>&1 || ! command -v ssh-add >/dev/null 2>&1; then
    skip "this machine has no ssh-agent to hold a key in"
  fi
  local agentkey="${WORK}/agentonly"
  ssh-keygen -q -t ed25519 -N '' -f "${agentkey}" </dev/null
  fixture_publish_keys "${SERVED}" "agentuser" "${agentkey}.pub"
  "${FUSHO_BIN}" send agentuser 'for the agent user' --no-clipboard >"${WORK}/agent.armored" 2>/dev/null
  local sock="/tmp/fusho-test-agent-$$.sock"
  rm -f "${sock}"
  local agent_env
  agent_env="$(ssh-agent -a "${sock}" -s)"
  eval "${agent_env}" >/dev/null
  ssh-add -q "${agentkey}" 2>/dev/null

  # Act
  HOME="${WORK}/stranger" run "${FUSHO_BIN}" read "${WORK}/agent.armored"

  # Assert
  ssh-agent -k >/dev/null 2>&1
  rm -f "${sock}"
  assert_status 1
  assert_output_contains "your ssh agent does hold one of these keys"
  assert_output_contains "--identity-command"
}

@test "stays quiet about agents when none holds the key" {
  # Arrange
  local expected_status=1

  # Act
  run "${FUSHO_BIN}" read "${WORK}/message" --identity "${WORK}/absent-key"

  # Assert
  assert_status "${expected_status}"
  assert_output_lacks "ssh agent does hold"
}

@test "reads the private key from a command" {
  # Arrange
  local expected_status=0

  # Act
  run "${FUSHO_BIN}" read "${WORK}/message" \
    --identity-command "cat ${WORK}/home/.ssh/id_ed25519_personal"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "the recovered secret"
}

@test "reports a failing identity command" {
  # Arrange
  local expected_status=1

  # Act
  run "${FUSHO_BIN}" read "${WORK}/message" --identity-command "false"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "identity command"
}

@test "reports an identity command that produces nothing" {
  # Arrange
  local expected_status=1

  # Act
  run "${FUSHO_BIN}" read "${WORK}/message" --identity-command "true"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "produced nothing"
}

@test "names the whole block when the paste is missing it" {
  # Arrange
  printf 'brew install gufranco/fusho/fusho\n' >"${WORK}/wrongpaste"

  # Act
  run "${FUSHO_BIN}" read "${WORK}/wrongpaste"

  # Assert
  assert_status 1
  assert_output_contains "copy the whole block"
}
