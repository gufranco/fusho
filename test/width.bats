load helpers/fixtures
load helpers/assertions

setup() {
  FAKES="$(mktemp -d /tmp/fusho-width.XXXXXX)"
  FAKES="$(cd "$FAKES" && pwd -P)"
}

teardown() {
  rm -rf "$FAKES"
}

widest_line() {
  awk '{ if (length($0) > widest) { widest = length($0) } } END { print widest + 0 }'
}

fake_sed() {
  local dir="$1" real
  real=$(command -v sed)
  mkdir -p "$dir"
  # shellcheck disable=SC2016
  printf '#!/bin/sh\n{ set +x; } 2>/dev/null\nif [ "${1:-}" = --version ]; then printf "sed (GNU sed) 4.9\\n"; exit 0; fi\nexec "%s" "$@"\n' "$real" >"${dir}/sed"
  chmod +x "${dir}/sed"
}

@test "help never prints a line wider than 80 columns" {
  # Arrange
  local page widest

  # Act
  page="$(FUSHO_TERMINAL=1 "$FUSHO_BIN" help)"

  # Assert
  widest="$(printf '%s\n' "$page" | widest_line)"
  [[ "$widest" -le 80 ]]
}

@test "version never prints a line wider than 80 columns" {
  # Arrange
  local page widest

  # Act
  page="$(FUSHO_TERMINAL=1 "$FUSHO_BIN" version)"

  # Assert
  widest="$(printf '%s\n' "$page" | widest_line)"
  [[ "$widest" -le 80 ]]
}

@test "an error longer than 80 columns wraps between words on a terminal" {
  # Arrange
  local option="--this-option-name-is-long-enough-to-push-the-usage-hint-past-eighty"

  # Act
  FUSHO_TERMINAL=1 run "$FUSHO_BIN" "$option"

  # Assert
  assert_status 1
  [[ "${#lines[@]}" -eq 3 ]]
  assert_equal "${lines[0]}" "fusho: unknown option"
  assert_equal "${lines[1]}" "'${option}'. run"
  assert_equal "${lines[2]}" "'fusho help' for usage."
}

@test "an error sent to a pipe stays on one line, however long" {
  # Arrange
  local option="--this-option-name-is-long-enough-to-push-the-usage-hint-past-eighty"

  # Act
  run "$FUSHO_BIN" "$option"

  # Assert
  assert_status 1
  assert_equal "$output" "fusho: unknown option '${option}'. run 'fusho help' for usage."
}

@test "a doctor row stays on one line on a terminal, however long" {
  # Arrange
  local dir="${FAKES}/a-folder-long-enough-to-pass-80"
  fake_sed "$dir"

  # Act
  FUSHO_TERMINAL=1 FUSHO_OS=Linux PATH="${dir}:${PATH}" run "$FUSHO_BIN" doctor

  # Assert
  assert_output_contains $'\n'"sed                ok       ${dir}/sed, gnu 4.9"$'\n'
}
