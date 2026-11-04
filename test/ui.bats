# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  WORK="$(fixture_workspace)"
  SERVED="${WORK}/served"
  mkdir -p "${SERVED}" "${WORK}/home/.ssh"
  fixture_generate_ed25519 "${WORK}/home/.ssh" "id_ed25519"
  fixture_generate_ed25519 "${WORK}/home/.ssh" "rotated"
  fixture_publish_keys "${SERVED}" "alice" "${WORK}/home/.ssh/id_ed25519.pub"
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
  export FUSHO_TEST_GUM=1
  export FUSHO_TEST_GUM_LOG="${WORK}/gum-${BATS_TEST_NUMBER}.log"
  export FUSHO_TEST_GUM_ANSWERS="${WORK}/answers-${BATS_TEST_NUMBER}"
  export FUSHO_INTERACTIVE=1
  export FUSHO_CLIPBOARD_PASTE=false
  export FUSHO_CLIPBOARD_COPY=true
  export FUSHO_CLIPBOARD_TIMEOUT=0
  unset KODOUGU_THEME KODOUGU_ACCENT FUSHO_THEME FUSHO_ACCENT NO_COLOR
  : >"${FUSHO_TEST_GUM_LOG}"
}

answers() {
  printf '%s\n' "$@" >"${FUSHO_TEST_GUM_ANSWERS}"
}

gum_called() {
  grep -q -F -- "$1" "${FUSHO_TEST_GUM_LOG}"
}

@test "the menu opens with the header and runs doctor from a gum choice" {
  # Arrange
  answers "Check this machine"

  # Act
  run "${FUSHO_BIN}" </dev/null

  # Assert
  assert_status 0
  assert_output_contains "send encrypted messages through any chat"
  assert_output_contains "Ready. Every tool fusho needs is here."
  gum_called "choose --header What would you like to do?"
}

@test "the menu sends a message typed into gum write" {
  # Arrange
  local payload
  payload="$(openssl rand -hex 16)"
  answers "Send a message" "alice" "${payload}"

  # Act
  run "${FUSHO_BIN}" </dev/null

  # Assert
  assert_status 0
  assert_output_contains "-----BEGIN FUSHO MESSAGE-----"
  assert_output_contains "ENCRYPTED WITH AGE"
  gum_called "input --header Send to --placeholder a GitHub user or user@host"
}

@test "the menu reads a message pasted into gum write" {
  # Arrange
  local payload armor
  payload="$(openssl rand -hex 16)"
  armor="$(printf '%s\n' "${payload}" | FUSHO_TEST_GUM=0 FUSHO_INTERACTIVE=0 "${FUSHO_BIN}" send alice --no-clipboard 2>/dev/null)"
  answers "Read a message" "${armor//$'\n'/\\n}"

  # Act
  run "${FUSHO_BIN}" </dev/null

  # Assert
  assert_status 0
  assert_output_contains "${payload}"
  gum_called "write --header Paste the fusho message"
}

@test "cancelling the paste box stops quietly" {
  # Arrange
  answers "Read a message" "<cancel>"

  # Act
  run "${FUSHO_BIN}" </dev/null

  # Assert
  assert_status 130
  assert_output_lacks "no fusho message found"
}

@test "the menu lists keys in a table" {
  # Arrange
  answers "List someone's keys" "alice"

  # Act
  run "${FUSHO_BIN}" </dev/null

  # Assert
  assert_status 0
  assert_output_contains "Fingerprint"
  assert_output_contains "ED25519"
  gum_called "spin --spinner dot"
}

@test "the menu shows the help page through gum format" {
  # Arrange
  answers "Help"

  # Act
  run "${FUSHO_BIN}" </dev/null

  # Assert
  assert_status 0
  assert_output_contains "## Usage"
  gum_called "format --theme pink"
}

@test "the menu stops when gum returns an answer it did not offer" {
  # Arrange
  answers "Something else"

  # Act
  run "${FUSHO_BIN}" </dev/null

  # Assert
  assert_status 1
}

@test "the menu stops when the choice is cancelled" {
  # Arrange
  answers "<cancel>"

  # Act
  run "${FUSHO_BIN}" </dev/null

  # Assert
  assert_status 1
}

@test "send refuses an empty message typed into gum write" {
  # Arrange
  answers ""

  # Act
  run "${FUSHO_BIN}" send alice --no-clipboard </dev/null

  # Assert
  assert_status 1
  assert_output_contains "ERROR fusho: refusing to send an empty message."
}

@test "send stops when gum write is cancelled" {
  # Arrange
  answers "<cancel>"

  # Act
  run "${FUSHO_BIN}" send alice --no-clipboard </dev/null

  # Assert
  assert_status 1
}

@test "send shows the signing and expiry badges" {
  # Arrange
  local payload
  payload="$(openssl rand -hex 16)"
  fixture_publish_keys "${SERVED}" "carol" "${WORK}/home/.ssh/id_ed25519.pub"

  # Act
  run "${FUSHO_BIN}" send alice "${payload}" --sign carol --expires 1d --no-clipboard </dev/null

  # Assert
  assert_status 0
  assert_output_contains "SIGNED AS carol"
  assert_output_contains "expires "
}

@test "an interrupted key fetch stops with status 130" {
  # Arrange
  local -a settings=(FUSHO_TEST_GUM_SPIN=cancel)

  # Act
  run env "${settings[@]}" "${FUSHO_BIN}" keys alice </dev/null

  # Assert
  assert_status 130
}

@test "a failed key fetch under the spinner reports its error" {
  # Arrange
  local nobody
  nobody="nobody-$(openssl rand -hex 4)"

  # Act
  run "${FUSHO_BIN}" keys "${nobody}" </dev/null

  # Assert
  assert_status 1
  assert_output_contains "ERROR fusho:"
}

@test "a first message lists the new fingerprints in a table" {
  # Arrange
  local payload
  payload="$(openssl rand -hex 16)"

  # Act
  run "${FUSHO_BIN}" send alice "${payload}" --no-clipboard </dev/null

  # Assert
  assert_status 0
  assert_output_contains "INFO fusho: first message to 'alice'"
  assert_output_contains "SHA256:"
}

@test "changed keys stop the send inside a danger box" {
  # Arrange
  fixture_publish_keys "${SERVED}" "dave" "${WORK}/home/.ssh/id_ed25519.pub"
  "${FUSHO_BIN}" send dave "first" --no-clipboard </dev/null >/dev/null 2>&1
  fixture_publish_keys "${SERVED}" "dave" "${WORK}/home/.ssh/rotated.pub"

  # Act
  run "${FUSHO_BIN}" send dave "second" --no-clipboard </dev/null

  # Assert
  assert_status 1
  assert_output_contains "The keys published by dave changed since you last messaged them."
  gum_called "--border thick"
}

@test "a warning is drawn with the WARN level" {
  # Arrange
  local payload
  payload="$(openssl rand -hex 16)"
  fixture_generate_rsa "${WORK}" "weak-${BATS_TEST_NUMBER}" 1024
  fixture_publish_keys "${SERVED}" "erin" "${WORK}/weak-${BATS_TEST_NUMBER}.pub" "${WORK}/home/.ssh/id_ed25519.pub"

  # Act
  run "${FUSHO_BIN}" send erin "${payload}" --no-clipboard </dev/null

  # Assert
  assert_status 0
  assert_output_contains "WARN fusho: 'erin' publishes a 1024-bit RSA key"
}

@test "doctor reports a missing tool below the table" {
  # Arrange
  local path
  path="$(sandbox_path_excluding "${WORK}/nocurl-${BATS_TEST_NUMBER}" curl)"

  # Act
  run env PATH="${path}" "${FUSHO_BIN}" doctor </dev/null

  # Assert
  assert_status 1
  assert_output_contains "ERROR fusho: 1 required tool(s) missing."
}

@test "doctor draws a missing key pair as a warning row" {
  # Arrange
  mkdir -p "${WORK}/bare-${BATS_TEST_NUMBER}"

  # Act
  run env HOME="${WORK}/bare-${BATS_TEST_NUMBER}" "${FUSHO_BIN}" doctor </dev/null

  # Assert
  assert_status 0
  assert_output_contains "identities"
  assert_output_contains "warn"
  assert_output_contains "no key pair found under ~/.ssh"
}

@test "version shows the version and engine as badges" {
  # Arrange
  local expected="fusho ${FUSHO_TEST_VERSION} engine age"

  # Act
  run "${FUSHO_BIN}" version </dev/null

  # Assert
  assert_status 0
  assert_equal "${output}" "${expected}"
}

@test "a long error stays on one line after its level" {
  # Arrange
  local option="--this-option-name-is-long-enough-to-push-the-usage-hint-past-eighty"

  # Act
  run "${FUSHO_BIN}" "${option}" </dev/null

  # Assert
  assert_status 1
  assert_equal "${output}" "ERROR fusho: unknown option '${option}'. run 'fusho help' for usage."
}

@test "--theme picks the palette over every environment setting" {
  # Arrange
  local -a settings=(KODOUGU_THEME=dracula FUSHO_THEME=gruvbox)

  # Act
  run env "${settings[@]}" "${FUSHO_BIN}" --theme nord version </dev/null

  # Assert
  assert_status 0
  gum_called "--background #88C0D0"
}

@test "--theme= with a value picks the palette" {
  # Arrange
  local theme="--theme=tokyo-night"

  # Act
  run "${FUSHO_BIN}" "${theme}" version </dev/null

  # Assert
  assert_status 0
  gum_called "--background #7AA2F7"
}

@test "FUSHO_THEME overrides KODOUGU_THEME" {
  # Arrange
  local -a settings=(KODOUGU_THEME=dracula FUSHO_THEME=catppuccin-latte)

  # Act
  run env "${settings[@]}" "${FUSHO_BIN}" version </dev/null

  # Assert
  assert_status 0
  gum_called "--background #8839EF"
}

@test "KODOUGU_THEME sets the palette for every member" {
  # Arrange
  local -a settings=(KODOUGU_THEME=catppuccin-mocha)

  # Act
  run env "${settings[@]}" "${FUSHO_BIN}" version </dev/null

  # Assert
  assert_status 0
  gum_called "--background #CBA6F7"
}

@test "an unknown theme stops with the list of themes" {
  # Arrange
  local -a settings=(KODOUGU_THEME=solarized)

  # Act
  run env "${settings[@]}" "${FUSHO_BIN}" version </dev/null

  # Assert
  assert_status 1
  assert_equal "${output}" "ERROR fusho: --theme must be one of kodougu, catppuccin-mocha, catppuccin-latte, dracula, nord, gruvbox, tokyo-night, mono, got: solarized"
}

@test "--theme without a value stops with the usage hint" {
  # Arrange
  local option="--theme"

  # Act
  run "${FUSHO_BIN}" version "${option}" </dev/null

  # Assert
  assert_status 1
  assert_output_contains "option '--theme' needs a value."
}

@test "--theme after -- is left to the command" {
  # Arrange
  local option="--theme"

  # Act
  run "${FUSHO_BIN}" send alice --no-clipboard -- "${option}" </dev/null

  # Assert
  assert_status 0
  assert_output_contains "-----BEGIN FUSHO MESSAGE-----"
}

@test "KODOUGU_ACCENT replaces the accent of the theme" {
  # Arrange
  local -a settings=(KODOUGU_ACCENT="#123456")

  # Act
  run env "${settings[@]}" "${FUSHO_BIN}" version </dev/null

  # Assert
  assert_status 0
  gum_called "--background #123456"
}

@test "KODOUGU_ACCENT must be a colour" {
  # Arrange
  local -a settings=(KODOUGU_ACCENT="pink")

  # Act
  run env "${settings[@]}" "${FUSHO_BIN}" version </dev/null

  # Assert
  assert_status 1
  assert_output_contains "KODOUGU_ACCENT must be a colour such as #CBA6F7, got: pink"
}

@test "NO_COLOR draws every theme without colour" {
  # Arrange
  local -a settings=(NO_COLOR=1 KODOUGU_THEME=nord)

  # Act
  run env "${settings[@]}" "${FUSHO_BIN}" version </dev/null

  # Assert
  assert_status 0
  gum_called "style --bold --underline --padding 0 1 -- fusho"
}

@test "the mono theme draws the doctor table without colour" {
  # Arrange
  local -a settings=(KODOUGU_THEME=mono)

  # Act
  run env "${settings[@]}" "${FUSHO_BIN}" doctor </dev/null

  # Assert
  assert_status 0
  assert_output_contains "Ready. Every tool fusho needs is here."
  gum_called "--border-foreground  --padding 0 1"
}

@test "the mono theme formats help as plain text" {
  # Arrange
  local -a settings=(KODOUGU_THEME=mono)

  # Act
  run env "${settings[@]}" "${FUSHO_BIN}" help </dev/null

  # Assert
  assert_status 0
  gum_called "format --theme ascii"
}

@test "the dracula theme uses its purple accent" {
  # Arrange
  local -a settings=(KODOUGU_THEME=dracula)

  # Act
  run env "${settings[@]}" "${FUSHO_BIN}" version </dev/null

  # Assert
  assert_status 0
  gum_called "--background #BD93F9"
}

@test "the gruvbox theme uses its orange accent" {
  # Arrange
  local -a settings=(KODOUGU_THEME=gruvbox)

  # Act
  run env "${settings[@]}" "${FUSHO_BIN}" version </dev/null

  # Assert
  assert_status 0
  gum_called "--background #FE8019"
}
