load helpers/fixtures
load helpers/assertions

setup_file() {
  load helpers/fixtures
  WORK="$(fixture_workspace)"
  XDG_CONFIG_HOME="${WORK}/config"
  SERVED="${WORK}/served"
  mkdir -p "$SERVED" "${WORK}/home/.ssh" "${WORK}/rsa"
  fixture_generate_ed25519 "${WORK}/home/.ssh" "id_ed25519"
  fixture_generate_rsa "${WORK}/rsa" "id_rsa" 3072
  fixture_publish_keys "$SERVED" "alice" "${WORK}/home/.ssh/id_ed25519.pub"
  fixture_publish_keys "$SERVED" "rsauser" "${WORK}/rsa/id_rsa.pub"
  keyserver_start "$SERVED"
  NOAGE="$(sandbox_path_excluding "${WORK}/bin-noage" age)"
  NOGZIP="$(sandbox_path_excluding "${WORK}/bin-nogzip" gzip)"
  export WORK SERVED FUSHO_GITHUB_BASE KEYSERVER_PID XDG_CONFIG_HOME NOAGE NOGZIP
}

teardown_file() {
  load helpers/fixtures
  keyserver_stop
  rm -rf "$WORK"
}

setup() {
  export HOME="${WORK}/home"
  SHIMS="$(mktemp -d "${WORK}/shims-XXXXXX")"
}

shim() {
  local name="$1" body="$2"
  printf '#!/bin/bash\n%s\n' "$body" >"${SHIMS}/${name}"
  chmod +x "${SHIMS}/${name}"
}

passthrough() {
  local name="$1" condition="$2" real
  real="$(command -v "$name")"
  shim "$name" "if ${condition}; then exit 1; fi
exec '${real}' \"\$@\""
}

wait_until_empty() {
  local file="$1" tries=0
  while [[ -s "$file" ]] && [[ "$tries" -lt 50 ]]; do
    sleep 0.1
    tries=$((tries + 1))
  done
}

@test "prints the raw expiry stamp when date cannot format it" {
  # Arrange
  "$FUSHO_BIN" send alice 'dated' --expires 1s --no-clipboard >"${WORK}/dated" 2>/dev/null
  sleep 2
  passthrough date '[[ " $* " == *" -r "* || " $* " == *" -d "* ]]'

  # Act
  run env PATH="${SHIMS}:${PATH}" "$FUSHO_BIN" read "${WORK}/dated"

  # Assert
  assert_status 1
  [[ "$output" =~ valid\ until\ [0-9]{10}\. ]]
}

@test "runs on a ksh that rejects local" {
  # Arrange
  local ksh
  ksh="$(command -v ksh93 || command -v ksh || true)"
  [[ -n "$ksh" ]] || skip "no ksh on this machine"
  ! "$ksh" -c 'f() { local x=1; }; f' 2>/dev/null || skip "this ksh supports local"

  # Act
  run "$ksh" "${FUSHO_REPO_ROOT}/bin/fusho" version

  # Assert
  assert_status 0
  assert_output_contains "fusho $(fixture_expected_version)"
}

@test "runs when bash has local disabled" {
  # Arrange
  local no_local="${WORK}/no-local.bash"
  printf 'enable -n local\n' >"$no_local"
  local runner=(bash "$FUSHO_BIN")
  [[ -z "${FUSHO_COVERAGE:-}" ]] || runner=("$FUSHO_BIN")

  # Act
  run env BASH_ENV="$no_local" "${runner[@]}" version

  # Assert
  assert_status 0
  assert_output_contains "fusho $(fixture_expected_version)"
}

@test "fails clearly when the RSA key size cannot be read" {
  # Arrange
  passthrough openssl '[[ " $* " == *" -text "* ]]'

  # Act
  run bash -c 'printf "x\n" | PATH="$1:$2" "$3" send rsauser --no-clipboard' _ "$SHIMS" "$NOAGE" "$FUSHO_BIN"

  # Assert
  assert_status 1
  assert_output_contains "could not determine the recipient RSA key size."
}

@test "fails clearly when age cannot encrypt" {
  # Arrange
  shim age 'exit 1'

  # Act
  run bash -c 'printf "x\n" | PATH="$1:$PATH" "$2" send alice --no-clipboard' _ "$SHIMS" "$FUSHO_BIN"

  # Assert
  assert_status 1
  assert_output_contains "age failed to encrypt the message."
}

@test "fails clearly when the RSA key cannot be converted to PKCS8" {
  # Arrange
  passthrough ssh-keygen '[[ " $* " == *" PKCS8 "* ]]'

  # Act
  run bash -c 'printf "x\n" | PATH="$1:$2" "$3" send rsauser --no-clipboard' _ "$SHIMS" "$NOAGE" "$FUSHO_BIN"

  # Assert
  assert_status 1
  assert_output_contains "could not convert the recipient SSH key to PKCS8."
}

@test "a passphrase key on a terminal is not refused for lack of a terminal" {
  # Arrange
  ssh-keygen -q -t ed25519 -N 'a-real-passphrase' -f "${WORK}/locked-tty" </dev/null
  fixture_publish_keys "$SERVED" "lockedtty" "${WORK}/locked-tty.pub"
  "$FUSHO_BIN" send lockedtty 'x' --no-clipboard >"${WORK}/to-locked" 2>/dev/null
  shim age 'exit 1'

  # Act
  run env PATH="${SHIMS}:${PATH}" python3 "${FUSHO_TEST_ROOT}/helpers/on_tty.py" \
    "$FUSHO_BIN" read --identity "${WORK}/locked-tty" "${WORK}/to-locked"

  # Assert
  assert_output_lacks "no terminal to prompt on"
}

@test "reports a missing key without consulting an absent ssh agent" {
  # Arrange
  "$FUSHO_BIN" send rsauser 'not for alice' --no-clipboard >"${WORK}/for-rsa" 2>/dev/null

  # Act
  run env -u SSH_AUTH_SOCK "$FUSHO_BIN" read "${WORK}/for-rsa"

  # Assert
  assert_status 1
  assert_output_lacks "ssh-agent"
}

@test "says nothing about the agent when it holds none of the message keys" {
  # Arrange
  if ! command -v ssh-agent >/dev/null 2>&1 || ! command -v ssh-add >/dev/null 2>&1; then
    skip "this machine has no ssh-agent to hold a key in"
  fi
  local agent="${WORK}/agent-unrelated"
  mkdir -p "$agent"
  fixture_generate_ed25519 "$agent" "unrelated"
  eval "$(ssh-agent -a "${agent}/sock" -s)" >/dev/null
  ssh-add -q "${agent}/unrelated" 2>/dev/null
  "$FUSHO_BIN" send rsauser 'not for this agent' --no-clipboard >"${WORK}/for-rsa-agent" 2>/dev/null

  # Act
  run env SSH_AUTH_SOCK="${agent}/sock" "$FUSHO_BIN" read "${WORK}/for-rsa-agent"
  ssh-agent -k >/dev/null

  # Assert
  assert_status 1
  assert_output_lacks "your ssh agent does hold"
}

@test "leaves the clipboard alone when the clear timeout is zero" {
  # Arrange
  local clip="${WORK}/clip-zero"

  # Act
  run env FUSHO_CLIPBOARD_COPY="tee ${clip}" FUSHO_CLIPBOARD_TIMEOUT=0 "$FUSHO_BIN" send alice 'kept'

  # Assert
  assert_status 0
  [[ -s "$clip" ]]
}

@test "clears the clipboard after the timeout when it still holds the message" {
  # Arrange
  local clip="${WORK}/clip-clear"

  # Act
  run env FUSHO_CLIPBOARD_COPY="tee ${clip}" FUSHO_CLIPBOARD_PASTE="cat ${clip}" FUSHO_CLIPBOARD_TIMEOUT=1 \
    "$FUSHO_BIN" send alice 'cleared'
  wait_until_empty "$clip"

  # Assert
  assert_status 0
  [[ ! -s "$clip" ]]
}

@test "sends uncompressed when gzip is not installed" {
  # Arrange
  local message="${WORK}/no-gzip-message"

  # Act
  run bash -c 'printf "%0500d\n" 0 | PATH="$1" "$2" send alice --no-clipboard >"$3"' _ "$NOGZIP" "$FUSHO_BIN" "$message"

  # Assert
  assert_status 0
  grep -q -- "-----BEGIN FUSHO MESSAGE-----" "$message"
}

@test "sends uncompressed when gzip fails" {
  # Arrange
  shim gzip 'exit 1'

  # Act
  run bash -c 'printf "%0500d\n" 0 | PATH="$1:$PATH" "$2" send alice --no-clipboard' _ "$SHIMS" "$FUSHO_BIN"

  # Assert
  assert_status 0
  assert_output_contains "-----BEGIN FUSHO MESSAGE-----"
}

@test "prints the message as a QR code with qrencode" {
  # Arrange
  shim qrencode 'printf "QR-CODE-OUTPUT\n"'

  # Act
  run bash -c 'printf "x\n" | PATH="$1:$PATH" "$2" send alice --qr --no-clipboard' _ "$SHIMS" "$FUSHO_BIN"

  # Assert
  assert_status 0
  assert_output_contains "QR-CODE-OUTPUT"
}

@test "fails clearly when signing fails" {
  # Arrange
  passthrough ssh-keygen '[[ " $* " == *" -Y sign "* ]]'

  # Act
  run bash -c 'printf "x\n" | PATH="$1:$PATH" "$2" send --sign alice alice --no-clipboard' _ "$SHIMS" "$FUSHO_BIN"

  # Assert
  assert_status 1
  assert_output_contains "signing failed with identity"
}
