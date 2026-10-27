load helpers/fixtures
load helpers/assertions

setup() {
  FAKES="$(mktemp -d "${BATS_TMPDIR:-/tmp}/fusho-flavor.XXXXXX")"
}

teardown() {
  rm -rf "$FAKES"
}

fake_tool() {
  local dir="$1" tool="$2" text="$3" real
  real=$(command -v "$tool")
  mkdir -p "$dir"
  # shellcheck disable=SC2016
  printf '#!/bin/sh\n{ set +x; } 2>/dev/null\nif [ "${1:-}" = --version ]; then printf "%%s\\n" "%s"; exit 0; fi\nexec "%s" "$@"\n' "$text" "$real" >"${dir}/${tool}"
  chmod +x "${dir}/${tool}"
}

doctor_row() {
  local tool="$1" os="$2"
  env PATH="${FAKES}/uutils-diffutils:${FAKES}:${PATH}" FUSHO_OS="$os" "$FUSHO_BIN" doctor | grep "^${tool} "
}

@test "doctor names GNU sed with its version" {
  # Arrange
  fake_tool "$FAKES" sed "sed (GNU sed) 4.9"

  # Act
  run doctor_row sed Linux

  # Assert
  assert_output_contains "${FAKES}/sed, gnu 4.9"
}

@test "doctor names Ubuntu's GNU coreutils as gnu" {
  # Arrange
  fake_tool "$FAKES" tr "tr (coreutils) 9.7"

  # Act
  run doctor_row tr Linux

  # Assert
  assert_output_contains "${FAKES}/tr, gnu 9.7"
}

@test "doctor names uutils coreutils with its version" {
  # Arrange
  fake_tool "$FAKES" tr "tr (uutils coreutils) 0.12.0"

  # Act
  run doctor_row tr Darwin

  # Assert
  assert_output_contains "${FAKES}/tr, uutils 0.12.0"
}

@test "doctor names mawk" {
  # Arrange
  fake_tool "$FAKES" awk "mawk 1.3.4 20260129"

  # Act
  run doctor_row awk Linux

  # Assert
  assert_output_contains "${FAKES}/awk, mawk 1.3.4"
}

@test "doctor names the BSD awk by its date stamp" {
  # Arrange
  fake_tool "$FAKES" awk "awk version 20200816"

  # Act
  run doctor_row awk Darwin

  # Assert
  assert_output_contains "${FAKES}/awk, bsd 20200816"
}

@test "doctor names BusyBox" {
  # Arrange
  fake_tool "$FAKES" date "BusyBox v1.36.1 (2024-06-10) multi-call binary."

  # Act
  run doctor_row date Linux

  # Assert
  assert_output_contains "${FAKES}/date, busybox 1.36.1"
}

@test "doctor reads a tool that refuses --version on macOS as bsd" {
  # Arrange
  fake_tool "$FAKES" date "date: illegal option -- -"

  # Act
  run doctor_row date Darwin

  # Assert
  assert_output_contains "${FAKES}/date, bsd"
}

@test "doctor reads a tool that refuses --version on Linux as unknown" {
  # Arrange
  fake_tool "$FAKES" date "date: unrecognized option"

  # Act
  run doctor_row date Linux

  # Assert
  assert_output_contains "${FAKES}/date, unknown"
}

@test "doctor names a uutils tool that refuses --version by where it lives" {
  # Arrange
  fake_tool "${FAKES}/uutils-diffutils" sed "sed: unrecognized option '--version'"

  # Act
  run doctor_row sed Darwin

  # Assert
  assert_output_contains "${FAKES}/uutils-diffutils/sed, uutils"
}
