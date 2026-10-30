# shellcheck source=test/helpers.bash
source "${BATS_TEST_DIRNAME:-.}/helpers.bash"

@test "loading the helpers swaps in a new wrapper and leaves the running one whole" {
  # Arrange
  local running="${BATS_TEST_TMPDIR:?}/running-wrapper"
  ln "${FUSHO_BIN}" "${running}"

  # Act
  source "${BATS_TEST_DIRNAME}/helpers.bash"

  # Assert
  [[ ! "${FUSHO_BIN}" -ef "${running}" ]]
  [[ -s "${running}" ]]
  [[ -x "${FUSHO_BIN}" ]]
}
