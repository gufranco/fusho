# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  WORK="$(fixture_workspace)"
  XDG_CONFIG_HOME="${WORK}/config"
  SERVED="${WORK}/served"
  mkdir -p "${SERVED}" "${WORK}/home/.ssh"
  fixture_generate_rsa_pem "${WORK}/home/.ssh" "id_rsa" 2048
  fixture_generate_rsa "${WORK}/home/.ssh" "id_rsa_openssh" 2048
  fixture_generate_ed25519 "${WORK}/home/.ssh" "id_ed25519"
  fixture_publish_keys "${SERVED}" "rsauser" "${WORK}/home/.ssh/id_rsa.pub"
  fixture_publish_keys "${SERVED}" "opensshuser" "${WORK}/home/.ssh/id_rsa_openssh.pub"
  fixture_publish_keys "${SERVED}" "curveuser" "${WORK}/home/.ssh/id_ed25519.pub"
  keyserver_start "${SERVED}"
  NOAGE="$(sandbox_path_excluding "${WORK}/bin-noage" age)"
  export WORK SERVED FUSHO_GITHUB_BASE KEYSERVER_PID XDG_CONFIG_HOME NOAGE
}

teardown_file() {
  keyserver_stop
  rm -rf "${WORK}"
}

setup() {
  export HOME="${WORK}/home"
}

@test "the sandbox path really has no age on it" {
  # Arrange
  local expected_status=1

  # Act
  run env PATH="${NOAGE}" bash -c 'command -v age'

  # Assert
  assert_status "${expected_status}"
}

@test "falls back to RSA and says so when age is absent" {
  # Arrange
  local expected_status=0

  # Act
  run env PATH="${NOAGE}" HOME="${WORK}/home" bash -c \
    "printf 'small secret\n' | '${FUSHO_BIN}' send rsauser --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "alg: rsa-oaep-sha1"
  assert_output_contains "falling back to RSA"
}

@test "round trips through the RSA fallback on both sides" {
  # Arrange
  printf 'fallback payload with acentuação\n' >"${WORK}/original"
  env PATH="${NOAGE}" HOME="${WORK}/home" "${FUSHO_BIN}" send rsauser --no-clipboard \
    <"${WORK}/original" >"${WORK}/armored" 2>/dev/null

  # Act
  env PATH="${NOAGE}" HOME="${WORK}/home" "${FUSHO_BIN}" read "${WORK}/armored" >"${WORK}/recovered"

  # Assert
  assert_files_identical "${WORK}/original" "${WORK}/recovered"
}

@test "refuses an Ed25519 recipient when age is absent" {
  # Arrange
  local expected_status=1

  # Act
  run env PATH="${NOAGE}" HOME="${WORK}/home" bash -c \
    "printf 'x\n' | '${FUSHO_BIN}' send curveuser --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "recipient key is not RSA"
  assert_output_contains "install age"
}

@test "refuses a message larger than the RSA key can carry" {
  # Arrange
  head -c 400 /dev/urandom >"${WORK}/toobig"

  # Act
  run env PATH="${NOAGE}" HOME="${WORK}/home" bash -c \
    "'${FUSHO_BIN}' send rsauser --no-clipboard < '${WORK}/toobig'"

  # Assert
  assert_status 1
  assert_output_contains "can carry only"
  assert_output_contains "install age"
}

@test "accepts a message exactly at the RSA capacity" {
  # Arrange
  head -c 214 /dev/urandom >"${WORK}/atlimit"

  # Act
  run env PATH="${NOAGE}" HOME="${WORK}/home" bash -c \
    "'${FUSHO_BIN}' send rsauser --no-clipboard < '${WORK}/atlimit'"

  # Assert
  assert_status 0
  assert_output_contains "alg: rsa-oaep-sha1"
}

@test "guides the user when the private key is in OpenSSH format" {
  # Arrange
  env PATH="${NOAGE}" HOME="${WORK}/home" "${FUSHO_BIN}" send opensshuser --no-clipboard \
    <<<"secret" >"${WORK}/openssh.armored" 2>/dev/null

  # Act
  run env PATH="${NOAGE}" HOME="${WORK}/home" "${FUSHO_BIN}" read "${WORK}/openssh.armored"

  # Assert
  assert_status 1
  assert_output_contains "ssh-keygen -p -m PEM"
}

@test "tells the recipient to install age when the message needs it" {
  # Arrange
  "${FUSHO_BIN}" send curveuser 'age only secret' --no-clipboard >"${WORK}/age.armored"

  # Act
  run env PATH="${NOAGE}" HOME="${WORK}/home" "${FUSHO_BIN}" read "${WORK}/age.armored"

  # Assert
  assert_status 1
  assert_output_contains "needs age to open"
}
