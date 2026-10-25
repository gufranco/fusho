load helpers/fixtures
load helpers/assertions

setup_file() {
  load helpers/fixtures
  WORK="$(fixture_workspace)"
  XDG_CONFIG_HOME="${WORK}/config"
  SERVED="${WORK}/served"
  mkdir -p "$SERVED" "${WORK}/.ssh"
  fixture_generate_ed25519 "${WORK}/.ssh" "id_ed25519"
  fixture_publish_keys "$SERVED" "alice" "${WORK}/.ssh/id_ed25519.pub"
  keyserver_start "$SERVED"
  export WORK SERVED FUSHO_GITHUB_BASE KEYSERVER_PID XDG_CONFIG_HOME
}

teardown_file() {
  load helpers/fixtures
  keyserver_stop
  rm -rf "$WORK"
}

setup() {
  export HOME="$WORK"
}

@test "carries a single line message unchanged" {
  local payload="deploy token ${RANDOM}${RANDOM}"

  run bash -c "printf '%s\n' '$payload' | '$FUSHO_BIN' send alice --no-clipboard | '$FUSHO_BIN' read"

  assert_status 0
  assert_output_contains "$payload"
}

@test "carries accented multi-line content byte for byte" {
  printf 'usuário: joão\nsenha: ação-çedilha\n' >"${WORK}/original"

  "$FUSHO_BIN" send alice --no-clipboard <"${WORK}/original" >"${WORK}/armored"
  "$FUSHO_BIN" read "${WORK}/armored" >"${WORK}/recovered"

  assert_files_identical "${WORK}/original" "${WORK}/recovered"
}

@test "carries a payload far beyond the RSA size ceiling" {
  head -c 5000 /dev/urandom | base64 >"${WORK}/big"

  "$FUSHO_BIN" send alice --no-clipboard <"${WORK}/big" >"${WORK}/big.armored"
  "$FUSHO_BIN" read "${WORK}/big.armored" >"${WORK}/big.recovered"

  assert_files_identical "${WORK}/big" "${WORK}/big.recovered"
}

@test "preserves trailing whitespace and blank lines" {
  printf 'line one   \n\n\nline four\n' >"${WORK}/spaced"

  "$FUSHO_BIN" send alice --no-clipboard <"${WORK}/spaced" >"${WORK}/spaced.armored"
  "$FUSHO_BIN" read "${WORK}/spaced.armored" >"${WORK}/spaced.recovered"

  assert_files_identical "${WORK}/spaced" "${WORK}/spaced.recovered"
}

@test "accepts the message as an argument" {
  run bash -c "'$FUSHO_BIN' send alice 'inline secret' --no-clipboard | '$FUSHO_BIN' read"

  assert_status 0
  assert_output_contains "inline secret"
}

@test "emits an armored block with the expected header fields" {
  run bash -c "printf 'x\n' | '$FUSHO_BIN' send alice --no-clipboard"

  assert_status 0
  assert_output_contains "-----BEGIN FUSHO MESSAGE-----"
  assert_output_contains "v: 1"
  assert_output_contains "alg: age"
  assert_output_contains "to: alice"
  assert_output_contains "-----END FUSHO MESSAGE-----"
}

@test "never leaks the plaintext into the armored output" {
  local payload="canary-${RANDOM}${RANDOM}"

  run bash -c "printf '%s\n' '$payload' | '$FUSHO_BIN' send alice --no-clipboard"

  assert_status 0
  assert_output_lacks "$payload"
}

@test "refuses to send an empty message" {
  run bash -c "printf '' | '$FUSHO_BIN' send alice --no-clipboard"

  assert_status 1
  assert_output_contains "refusing to send an empty message"
}

@test "reads a message armored under the former osm name" {
  local payload="legacy secret ${RANDOM}"
  "$FUSHO_BIN" send alice --no-clipboard "$payload" | sed 's/ FUSHO MESSAGE-----$/ OSM MESSAGE-----/' >"${WORK}/legacy"

  run "$FUSHO_BIN" read "${WORK}/legacy"

  assert_status 0
  assert_output_contains "$payload"
}

@test "moves a trust store kept under the former osm name" {
  local config="${WORK}/migrate-config"
  mkdir -p "${config}/osm"
  printf 'carol SHA256:legacy\n' >"${config}/osm/known_recipients"

  run env XDG_CONFIG_HOME="$config" "$FUSHO_BIN" send alice --no-clipboard 'hello'

  assert_status 0
  [[ -f "${config}/fusho/known_recipients" ]]
  [[ ! -e "${config}/osm" ]]
  grep -q '^carol SHA256:legacy$' "${config}/fusho/known_recipients"
}
