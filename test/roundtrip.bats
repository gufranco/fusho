# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  WORK="$(fixture_workspace)"
  XDG_CONFIG_HOME="${WORK}/config"
  SERVED="${WORK}/served"
  mkdir -p "${SERVED}" "${WORK}/.ssh"
  fixture_generate_ed25519 "${WORK}/.ssh" "id_ed25519"
  fixture_publish_keys "${SERVED}" "alice" "${WORK}/.ssh/id_ed25519.pub"
  keyserver_start "${SERVED}"
  export WORK SERVED FUSHO_GITHUB_BASE KEYSERVER_PID XDG_CONFIG_HOME
}

teardown_file() {
  keyserver_stop
  rm -rf "${WORK}"
}

setup() {
  export HOME="${WORK}"
}

@test "carries a single line message unchanged" {
  # Arrange
  local payload="deploy token ${RANDOM}${RANDOM}"

  # Act
  run bash -c "printf '%s\n' '${payload}' | '${FUSHO_BIN}' send alice --no-clipboard | '${FUSHO_BIN}' read"

  # Assert
  assert_status 0
  assert_output_contains "${payload}"
}

@test "carries accented multi-line content byte for byte" {
  # Arrange
  printf 'usuário: joão\nsenha: ação-çedilha\n' >"${WORK}/original"
  "${FUSHO_BIN}" send alice --no-clipboard <"${WORK}/original" >"${WORK}/armored"

  # Act
  "${FUSHO_BIN}" read "${WORK}/armored" >"${WORK}/recovered"

  # Assert
  assert_files_identical "${WORK}/original" "${WORK}/recovered"
}

@test "carries a payload far beyond the RSA size ceiling" {
  # Arrange
  openssl rand -base64 5000 >"${WORK}/big"
  "${FUSHO_BIN}" send alice --no-clipboard <"${WORK}/big" >"${WORK}/big.armored"

  # Act
  "${FUSHO_BIN}" read "${WORK}/big.armored" >"${WORK}/big.recovered"

  # Assert
  assert_files_identical "${WORK}/big" "${WORK}/big.recovered"
}

@test "preserves trailing whitespace and blank lines" {
  # Arrange
  printf 'line one   \n\n\nline four\n' >"${WORK}/spaced"
  "${FUSHO_BIN}" send alice --no-clipboard <"${WORK}/spaced" >"${WORK}/spaced.armored"

  # Act
  "${FUSHO_BIN}" read "${WORK}/spaced.armored" >"${WORK}/spaced.recovered"

  # Assert
  assert_files_identical "${WORK}/spaced" "${WORK}/spaced.recovered"
}

@test "accepts the message as an argument" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "'${FUSHO_BIN}' send alice 'inline secret' --no-clipboard | '${FUSHO_BIN}' read"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "inline secret"
}

@test "emits an armored block with the expected header fields" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "-----BEGIN FUSHO MESSAGE-----"
  assert_output_contains "v: 1"
  assert_output_contains "alg: age"
  assert_output_contains "to: alice"
  assert_output_contains "-----END FUSHO MESSAGE-----"
}

@test "never leaks the plaintext into the armored output" {
  # Arrange
  local payload="canary-${RANDOM}${RANDOM}"

  # Act
  run bash -c "printf '%s\n' '${payload}' | '${FUSHO_BIN}' send alice --no-clipboard"

  # Assert
  assert_status 0
  assert_output_lacks "${payload}"
}

@test "refuses to send an empty message" {
  # Arrange
  local expected_status=1

  # Act
  run bash -c "printf '' | '${FUSHO_BIN}' send alice --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "refusing to send an empty message"
}

@test "reads a message armored under the former osm name" {
  # Arrange
  local payload="legacy secret ${RANDOM}"
  local armored
  armored="$("${FUSHO_BIN}" send alice --no-clipboard "${payload}")"
  printf '%s\n' "${armored}" | sed 's/ FUSHO MESSAGE-----$/ OSM MESSAGE-----/' >"${WORK}/legacy"

  # Act
  run "${FUSHO_BIN}" read "${WORK}/legacy"

  # Assert
  assert_status 0
  assert_output_contains "${payload}"
}

@test "moves a trust store kept under the former osm name" {
  # Arrange
  local config="${WORK}/migrate-config"
  mkdir -p "${config}/osm"
  printf 'carol SHA256:legacy\n' >"${config}/osm/known_recipients"

  # Act
  run env XDG_CONFIG_HOME="${config}" "${FUSHO_BIN}" send alice --no-clipboard 'hello'

  # Assert
  assert_status 0
  [[ -f "${config}/fusho/known_recipients" ]]
  [[ ! -e "${config}/osm" ]]
  grep -q '^carol SHA256:legacy$' "${config}/fusho/known_recipients"
}
