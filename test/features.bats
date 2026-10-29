# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

setup_file() {
  WORK="$(fixture_workspace)"
  XDG_CONFIG_HOME="${WORK}/config"
  SERVED="${WORK}/served"
  mkdir -p "${SERVED}" "${WORK}/home/.ssh"
  fixture_generate_ed25519 "${WORK}/home/.ssh" "id_ed25519"
  fixture_generate_rsa "${WORK}/home/.ssh" "weak" 2048
  fixture_generate_rsa "${WORK}/home/.ssh" "strong" 4096
  fixture_publish_keys "${SERVED}" "alice" "${WORK}/home/.ssh/id_ed25519.pub"
  fixture_publish_keys "${SERVED}" "weakuser" "${WORK}/home/.ssh/weak.pub"
  fixture_publish_keys "${SERVED}" "stronguser" "${WORK}/home/.ssh/strong.pub"
  keyserver_start "${SERVED}"
  NOQR="$(sandbox_path_excluding "${WORK}/bin-noqr" qrencode)"
  export WORK SERVED FUSHO_GITHUB_BASE KEYSERVER_PID XDG_CONFIG_HOME NOQR
}

teardown_file() {
  keyserver_stop
  rm -rf "${WORK}"
}

setup() {
  export HOME="${WORK}/home"
}

@test "compresses a repetitive payload and marks the encoding" {
  # Arrange
  printf '%*s' 4000 '' | tr ' ' 'a' >"${WORK}/repetitive"
  "${FUSHO_BIN}" send alice --no-clipboard <"${WORK}/repetitive" >"${WORK}/rep.armored" 2>/dev/null

  # Act
  run grep -c '^enc: gzip' "${WORK}/rep.armored"

  # Assert
  assert_status 0
}

@test "a compressed payload survives the round trip" {
  # Arrange
  printf '%*s' 4000 '' | tr ' ' 'b' >"${WORK}/rep2"
  "${FUSHO_BIN}" send alice --no-clipboard <"${WORK}/rep2" >"${WORK}/rep2.armored" 2>/dev/null

  # Act
  "${FUSHO_BIN}" read "${WORK}/rep2.armored" >"${WORK}/rep2.recovered"

  # Assert
  assert_files_identical "${WORK}/rep2" "${WORK}/rep2.recovered"
}

@test "compression shrinks the message it produces" {
  # Arrange
  printf '%*s' 4000 '' | tr ' ' 'c' >"${WORK}/rep3"

  # Act
  "${FUSHO_BIN}" send alice --no-clipboard <"${WORK}/rep3" >"${WORK}/rep3.armored" 2>/dev/null

  # Assert
  local size
  size="$(wc -c <"${WORK}/rep3.armored")"
  [[ "${size}" -lt 2000 ]]
}

@test "an incompressible payload is left uncompressed" {
  # Arrange
  head -c 3000 /dev/urandom >"${WORK}/random"
  "${FUSHO_BIN}" send alice --no-clipboard <"${WORK}/random" >"${WORK}/random.armored" 2>/dev/null

  # Act
  run grep -c '^enc:' "${WORK}/random.armored"

  # Assert
  assert_status 1
}

@test "an incompressible payload still round trips" {
  # Arrange
  head -c 3000 /dev/urandom >"${WORK}/random2"
  "${FUSHO_BIN}" send alice --no-clipboard <"${WORK}/random2" >"${WORK}/random2.armored" 2>/dev/null

  # Act
  "${FUSHO_BIN}" read "${WORK}/random2.armored" >"${WORK}/random2.recovered"

  # Assert
  assert_files_identical "${WORK}/random2" "${WORK}/random2.recovered"
}

@test "warns about an RSA key below the modern floor" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send weakuser --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "2048-bit RSA key"
  assert_output_contains "rotate to ed25519"
}

@test "stays quiet about an RSA key at or above the floor" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send stronguser --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_lacks "below the"
}

@test "explains how to install qrencode when --qr cannot run" {
  # Arrange
  local expected_status=1

  # Act
  run env PATH="${NOQR}" HOME="${WORK}/home" bash -c \
    "printf 'x\n' | '${FUSHO_BIN}' send alice --qr --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "needs qrencode"
}

@test "compression raises what fits through the RSA fallback" {
  # Arrange
  local noage
  noage="$(sandbox_path_excluding "${WORK}/bin-noage-compress" age)"
  printf '%*s' 900 '' | tr ' ' 'd' >"${WORK}/bigrepeat"

  # Act
  run env PATH="${noage}" HOME="${WORK}/home" bash -c \
    "'${FUSHO_BIN}' send stronguser --no-clipboard < '${WORK}/bigrepeat'"

  # Assert
  assert_status 0
  assert_output_contains "alg: rsa-oaep-sha1"
}

@test "an expiring message carries an exp header" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --expires 1h --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "exp: "
}

@test "a message inside its window still opens" {
  # Arrange
  "${FUSHO_BIN}" send alice 'still fresh' --expires 1h --no-clipboard >"${WORK}/fresh" 2>/dev/null

  # Act
  run "${FUSHO_BIN}" read "${WORK}/fresh"

  # Assert
  assert_status 0
  assert_output_contains "still fresh"
}

@test "an expired message is refused with the deadline shown" {
  # Arrange
  "${FUSHO_BIN}" send alice 'gone stale' --expires 1s --no-clipboard >"${WORK}/stale" 2>/dev/null
  sleep 2

  # Act
  run "${FUSHO_BIN}" read "${WORK}/stale"

  # Assert
  assert_status 1
  assert_output_contains "expired"
  assert_output_contains "--ignore-expiry"
  assert_output_lacks "gone stale"
}

@test "an expired message opens under --ignore-expiry" {
  # Arrange
  "${FUSHO_BIN}" send alice 'stale but wanted' --expires 1s --no-clipboard >"${WORK}/stale2" 2>/dev/null
  sleep 2

  # Act
  run "${FUSHO_BIN}" read "${WORK}/stale2" --ignore-expiry

  # Assert
  assert_status 0
  assert_output_contains "stale but wanted"
}

@test "a malformed duration is rejected" {
  # Arrange
  local expected_status=1

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --expires soon --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "duration"
}

@test "an unknown duration unit is rejected" {
  # Arrange
  local expected_status=1

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --expires 5y --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "unknown duration unit"
}

@test "the expiry deadline is rendered as a readable date" {
  # Arrange
  "${FUSHO_BIN}" send alice 'x' --expires 1s --no-clipboard >"${WORK}/stale3" 2>/dev/null
  sleep 2

  # Act
  run "${FUSHO_BIN}" read "${WORK}/stale3"

  # Assert
  assert_status 1
  assert_output_contains "UTC"
}

@test "a custom clipboard command is used for copying" {
  # Arrange
  local expected_status=0

  # Act
  run env HOME="${WORK}/home" FUSHO_CLIPBOARD_COPY="tee ${WORK}/custom-clip" bash -c \
    "printf 'x\n' | '${FUSHO_BIN}' send alice"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "copied to the clipboard with tee"
}

@test "a custom clipboard command is used for reading" {
  # Arrange
  "${FUSHO_BIN}" send alice 'from a custom clipboard' --no-clipboard >"${WORK}/custom.armored" 2>/dev/null

  # Act
  run env HOME="${WORK}/home" FUSHO_CLIPBOARD_PASTE="cat ${WORK}/custom.armored" \
    "${FUSHO_BIN}" read --clipboard

  # Assert
  assert_status 0
  assert_output_contains "from a custom clipboard"
}

@test "the first contact warning lists the fingerprints to verify" {
  # Arrange
  export XDG_CONFIG_HOME="${WORK}/fresh-pin-store"
  mkdir -p "${XDG_CONFIG_HOME}"

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --no-clipboard"

  # Assert
  assert_status 0
  assert_output_contains "verify these fingerprints out of band"
  assert_output_contains "SHA256:"
}

@test "accepts a duration in minutes" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --expires 30m --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "exp: "
}

@test "accepts a duration in days" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --expires 7d --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "exp: "
}

@test "accepts a bare duration in seconds" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --expires 3600 --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_contains "exp: "
}

@test "refuses to decrypt with a passphrase key when no terminal exists" {
  # Arrange
  ssh-keygen -q -t ed25519 -N 'a-real-passphrase' -f "${WORK}/locked" </dev/null
  fixture_publish_keys "${SERVED}" "lockeduser" "${WORK}/locked.pub"
  "${FUSHO_BIN}" send lockeduser 'needs a prompt' --no-clipboard >"${WORK}/locked.armored" 2>/dev/null

  # Act
  run "${FUSHO_BIN}" read "${WORK}/locked.armored" --identity "${WORK}/locked" </dev/null

  # Assert
  assert_status 1
  assert_output_contains "passphrase protected"
}

@test "explains that gunzip is needed to open a compressed message" {
  # Arrange
  local nogzip
  nogzip="$(sandbox_path_excluding "${WORK}/bin-nogunzip" gunzip)"
  printf '%*s' 4000 '' | tr ' ' 'e' >"${WORK}/gz"
  "${FUSHO_BIN}" send alice --no-clipboard <"${WORK}/gz" >"${WORK}/gz.armored" 2>/dev/null

  # Act
  run env PATH="${nogzip}" HOME="${WORK}/home" "${FUSHO_BIN}" read "${WORK}/gz.armored"

  # Assert
  assert_status 1
  assert_output_contains "gunzip is not installed"
}

@test "refuses a QR code for a message too large to encode" {
  # Arrange
  if ! command -v qrencode >/dev/null 2>&1; then
    skip "qrencode is not installed on this machine"
  fi
  head -c 9000 /dev/urandom >"${WORK}/huge"

  # Act
  run bash -c "'${FUSHO_BIN}' send alice --qr --no-clipboard < '${WORK}/huge'"

  # Assert
  assert_status 1
  assert_output_contains "too large for a QR code"
}

@test "the banner tells a newcomer what the block is and how to open it" {
  # Arrange
  local recipient="alice"

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send ${recipient} --no-clipboard"

  # Assert
  assert_status 0
  assert_output_contains "This is an encrypted message"
  assert_output_contains "brew install gufranco/tap/fusho"
  assert_output_contains "fusho read"
}

@test "the banner sits above the block so it cannot corrupt parsing" {
  # Arrange
  "${FUSHO_BIN}" send alice 'banner safe' --no-clipboard >"${WORK}/bannered" 2>/dev/null

  # Act
  run "${FUSHO_BIN}" read "${WORK}/bannered"

  # Assert
  assert_status 0
  assert_output_contains "banner safe"
}

@test "the banner never appears inside the armored block" {
  # Arrange
  "${FUSHO_BIN}" send alice 'x' --no-clipboard >"${WORK}/inside" 2>/dev/null

  # Act
  run awk '/^-----BEGIN FUSHO MESSAGE-----$/,/^-----END FUSHO MESSAGE-----$/' "${WORK}/inside"

  # Assert
  assert_status 0
  assert_output_lacks "This is an encrypted message"
  assert_output_lacks "brew tap"
}

@test "--no-banner omits it" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --no-banner --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_lacks "This is an encrypted message"
  assert_output_contains "-----BEGIN FUSHO MESSAGE-----"
}

@test "FUSHO_BANNER=0 omits it" {
  # Arrange
  local expected_status=0

  # Act
  run env HOME="${WORK}/home" FUSHO_BANNER=0 bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_lacks "This is an encrypted message"
  assert_output_contains "-----BEGIN FUSHO MESSAGE-----"
}

@test "json output carries no banner" {
  # Arrange
  local expected_status=0

  # Act
  run bash -c "printf 'x\n' | '${FUSHO_BIN}' send alice --json --no-clipboard"

  # Assert
  assert_status "${expected_status}"
  assert_output_lacks "This is an encrypted message"
  assert_output_contains '"alg":"age"'
}

@test "the clipboard receives the banner along with the block" {
  # Arrange
  local expected_status=0

  # Act
  run env HOME="${WORK}/home" FUSHO_CLIPBOARD_COPY="tee ${WORK}/banner-clip" bash -c \
    "printf 'x\n' | '${FUSHO_BIN}' send alice"

  # Assert
  assert_status "${expected_status}"
  run cat "${WORK}/banner-clip"
  assert_output_contains "This is an encrypted message"
  assert_output_contains "-----END FUSHO MESSAGE-----"
}
