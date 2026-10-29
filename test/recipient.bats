# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  WORK="$(fixture_workspace)"
  XDG_CONFIG_HOME="${WORK}/config"
  SERVED="${WORK}/served"
  mkdir -p "${SERVED}" "${WORK}/keys"
  fixture_generate_ed25519 "${WORK}/keys" "one"
  fixture_generate_ed25519 "${WORK}/keys" "two"
  fixture_generate_rsa "${WORK}/keys" "rsa" 2048
  fixture_generate_ecdsa "${WORK}/keys" "curve"
  fixture_publish_keys "${SERVED}" "solo" "${WORK}/keys/one.pub"
  fixture_publish_keys "${SERVED}" "multi" "${WORK}/keys/one.pub" "${WORK}/keys/two.pub"
  fixture_publish_keys "${SERVED}" "mixed" "${WORK}/keys/one.pub" "${WORK}/keys/curve.pub"
  fixture_publish_keys "${SERVED}" "curveonly" "${WORK}/keys/curve.pub"
  fixture_publish_empty_account "${SERVED}" "barren"
  keyserver_start "${SERVED}"
  FP_ONE="$(fixture_fingerprint "${WORK}/keys/one.pub")"
  FP_TWO="$(fixture_fingerprint "${WORK}/keys/two.pub")"
  export WORK SERVED FUSHO_GITHUB_BASE KEYSERVER_PID XDG_CONFIG_HOME FP_ONE FP_TWO
}

teardown_file() {
  keyserver_stop
  rm -rf "${WORK}"
}

@test "reports a GitHub account that does not exist" {
  # Arrange
  local expected_status=1

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send ghost --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "no account 'ghost' at github"
}

@test "reports an account that publishes no keys" {
  # Arrange
  local expected_status=1

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send barren --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "has no SSH keys published"
}

@test "reports an account whose keys are all unsupported types" {
  # Arrange
  local expected_status=1

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send curveonly --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "publishes no key fusho can encrypt to"
  assert_output_contains "ecdsa-sha2-nistp256"
}

@test "ignores unsupported key types when a supported one is present" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send mixed --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "key: ${FP_ONE}"
  assert_output_lacks "ecdsa"
}

@test "addresses every supported key by default" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send multi --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "key: ${FP_ONE}"
  assert_output_contains "key: ${FP_TWO}"
}

@test "pins a single key when a fingerprint prefix is supplied" {
  # Arrange
  local prefix=${FP_TWO#SHA256:}

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send 'multi:${prefix}' --no-clipboard"

  # Assert
  assert_status 0
  assert_output_contains "key: ${FP_TWO}"
  assert_output_lacks "key: ${FP_ONE}"
}

@test "pins a single key through the --key flag" {
  # Arrange
  local prefix=${FP_ONE#SHA256:}

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send multi --key '${prefix}' --no-clipboard"

  # Assert
  assert_status 0
  assert_output_contains "key: ${FP_ONE}"
  assert_output_lacks "key: ${FP_TWO}"
}

@test "rejects a fingerprint prefix that matches nothing and lists the choices" {
  # Arrange
  local expected_status=1

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send multi --key zzzznomatch --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "matches fingerprint prefix zzzznomatch"
  assert_output_contains "${FP_ONE}"
  assert_output_contains "${FP_TWO}"
}

@test "rejects an ambiguous fingerprint prefix and lists the matches" {
  # Arrange
  local expected_status=1

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send multi --key 'SHA256:' --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "is ambiguous"
  assert_output_contains "${FP_ONE}"
  assert_output_contains "${FP_TWO}"
}

@test "lists an account's usable keys with fingerprints" {
  # Arrange
  local expected_status=0

  # Act
  run "${FUSHO_BIN}" keys multi

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "${FP_ONE}"
  assert_output_contains "${FP_TWO}"
  assert_output_contains "ED25519"
}

@test "reports an unreachable key server" {
  # Arrange
  local expected_status=1

  # Act
  FUSHO_GITHUB_BASE="http://127.0.0.1:1" run bash -c "printf 'x\n' | '${FUSHO_BIN}' send solo --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "could not reach"
}

@test "addresses several recipients in one message" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send --to solo --to multi --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "to: solo"
  assert_output_contains "to: multi"
}

@test "accepts a local public key file as a recipient" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send --keys-file '${WORK}/keys/one.pub' --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "key: ${FP_ONE}"
  assert_output_contains "to: one.pub"
}

@test "rejects a key file that does not exist" {
  # Arrange
  local expected_status=1

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send --keys-file '${WORK}/absent.pub' --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "does not exist"
}

@test "emits machine readable output with --json" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send solo --json --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains '"alg":"age"'
  assert_output_contains '"to":["solo"]'
  assert_output_contains "BEGIN FUSHO MESSAGE"
}

@test "a JSON array escapes control characters, quotes and backslashes" {
  # Arrange
  printf '%s\n' "$(printf 'a\tb')" 'say "hi" \ now' >"${WORK}/lines"

  # Act
  run fusho_test_call fusho_json_array "${WORK}/lines"

  # Assert
  assert_status 0
  assert_equal "${output}" '["a\u0009b","say \"hi\" \\ now"]'
}

@test "resolves the key host from the recipient suffix" {
  # Arrange
  local expected_status=0

  # Act
  run "${FUSHO_BIN}" keys-url alice@gitlab

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "https://gitlab.com/alice.keys"
}

@test "refuses Bitbucket with a concrete remedy" {
  # Arrange
  local expected_status=1

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice@bitbucket --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "no public SSH key endpoint"
  assert_output_contains "--keys-file"
}

@test "treats an unknown host as a self-hosted forge" {
  # Arrange
  local expected_status=0

  # Act
  run "${FUSHO_BIN}" keys-url alice@git.example.com

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "https://git.example.com/alice.keys"
}

@test "resolves the codeberg host" {
  # Arrange
  local expected_status=0

  # Act
  run "${FUSHO_BIN}" keys-url alice@codeberg

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "https://codeberg.org/alice.keys"
}

@test "resolves the sourcehut host with its tilde convention" {
  # Arrange
  local expected_status=0

  # Act
  run "${FUSHO_BIN}" keys-url alice@sourcehut

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "https://meta.sr.ht/~alice.keys"
}

@test "accepts the srht alias for sourcehut" {
  # Arrange
  local expected_status=0

  # Act
  run "${FUSHO_BIN}" keys-url alice@srht

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "https://meta.sr.ht/~alice.keys"
}

@test "rejects a key file holding no usable key" {
  # Arrange
  local expected_status=1

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send --keys-file '${WORK}/keys/curve.pub' --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "no usable recipient key"
}
