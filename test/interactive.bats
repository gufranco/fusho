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
  export FUSHO_INTERACTIVE=1
  export FUSHO_CLIPBOARD_PASTE=false
}

answering() {
  local answers="$1"
  shift
  printf '%b' "${answers}" | "${FUSHO_BIN}" "$@"
}

@test "the menu runs doctor when asked to check this machine" {
  # Arrange
  local answers='4\n'

  # Act
  run answering "${answers}"

  # Assert
  assert_status 0
  assert_output_contains "What would you like to do?"
  assert_output_contains "age"
}

@test "the menu rejects a choice it does not offer" {
  # Arrange
  local answers='9\n'

  # Act
  run answering "${answers}"

  # Assert
  assert_status 1
  assert_output_contains "fusho: unknown choice '9'. run 'fusho help' for usage."
}

@test "the menu stops when input ends before a choice" {
  # Arrange
  local answers=''

  # Act
  run answering "${answers}"

  # Assert
  assert_status 1
}

@test "send asks for the recipient and encrypts the typed message" {
  # Arrange
  local payload
  payload="$(openssl rand -hex 16)"

  # Act
  run answering "alice\n${payload}\n" send --no-clipboard

  # Assert
  assert_status 0
  assert_output_contains "Send to, a GitHub user or user@host:"
  assert_output_contains "Type the message, then press Ctrl-D on an empty line:"
  assert_output_contains "-----BEGIN FUSHO MESSAGE-----"
}

@test "send gives up after three empty recipients" {
  # Arrange
  local answers='\n\n\n'

  # Act
  run answering "${answers}" send --no-clipboard

  # Assert
  assert_status 1
  assert_output_contains "fusho: no recipient given. run 'fusho help' for usage."
}

@test "keys asks whose keys to list" {
  # Arrange
  local answers='alice\n'

  # Act
  run answering "${answers}" keys

  # Assert
  assert_status 0
  assert_output_contains "Whose keys, a GitHub user or user@host:"
  assert_output_contains "ED25519"
}

@test "keys gives up after three empty answers" {
  # Arrange
  local answers='\n\n\n'

  # Act
  run answering "${answers}" keys

  # Assert
  assert_status 1
  assert_output_contains "fusho: no user given. run 'fusho help' for usage."
}

@test "read asks for a paste when the clipboard holds no message" {
  # Arrange
  local payload armor recovered
  payload="$(openssl rand -hex 16)"
  armor="${WORK}/pasted.txt"
  recovered="${WORK}/recovered.txt"
  printf '%s\n' "${payload}" | FUSHO_INTERACTIVE=0 "${FUSHO_BIN}" send alice --no-clipboard >"${armor}"

  # Act
  run bash -c '"$1" read <"$2" 2>"$3.err" >"$3"; status=$?; cat "$3.err"; exit "$status"' _ "${FUSHO_BIN}" "${armor}" "${recovered}"

  # Assert
  assert_status 0
  assert_output_contains "Paste the fusho message, then press Ctrl-D on an empty line:"
  assert_equal "$(cat "${recovered}" || true)" "${payload}"
}

@test "the menu sends a message when asked to send" {
  # Arrange
  local payload clip
  payload="$(openssl rand -hex 16)"
  clip="${WORK}/menu-clip"
  export FUSHO_CLIPBOARD_COPY="tee ${clip}"

  # Act
  run answering "1\nalice\n${payload}\n"

  # Assert
  assert_status 0
  grep -q -- "-----BEGIN FUSHO MESSAGE-----" "${clip}"
}

@test "the menu reads a pasted message when asked to read" {
  # Arrange
  local payload armor
  payload="$(openssl rand -hex 16)"
  armor="$(printf '%s\n' "${payload}" | FUSHO_INTERACTIVE=0 "${FUSHO_BIN}" send alice --no-clipboard)"

  # Act
  run answering "2\n${armor}\n"

  # Assert
  assert_status 0
  assert_output_contains "${payload}"
}

@test "the menu lists keys when asked to" {
  # Arrange
  local answers='3\nalice\n'

  # Act
  run answering "${answers}"

  # Assert
  assert_status 0
  assert_output_contains "ED25519"
}

@test "read asks for a paste when the clipboard holds something else" {
  # Arrange
  local payload armor recovered
  payload="$(openssl rand -hex 16)"
  armor="${WORK}/pasted-other.txt"
  recovered="${WORK}/recovered-other.txt"
  printf '%s\n' "${payload}" | FUSHO_INTERACTIVE=0 "${FUSHO_BIN}" send alice --no-clipboard >"${armor}"
  export FUSHO_CLIPBOARD_PASTE="printf unrelated-text"

  # Act
  run bash -c '"$1" read <"$2" 2>"$3.err" >"$3"; status=$?; cat "$3.err"; exit "$status"' _ "${FUSHO_BIN}" "${armor}" "${recovered}"

  # Assert
  assert_status 0
  assert_output_contains "Paste the fusho message, then press Ctrl-D on an empty line:"
  assert_equal "$(cat "${recovered}" || true)" "${payload}"
}
