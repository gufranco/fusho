#!/usr/bin/env bash

FUSHO_TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FUSHO_REPO_ROOT="$(cd "${FUSHO_TESTS_DIR}/.." && pwd)"
FUSHO_BIN="${BATS_RUN_TMPDIR:-${TMPDIR:-/tmp}}/fusho-under-test"
read -r -a fusho_shell_words <<<"${FUSHO_TEST_SHELL:-sh}"
fusho_shell_words[0]="$(command -v "${fusho_shell_words[0]}")"
fusho_bin_next="$(mktemp "${FUSHO_BIN}.XXXXXX")"
printf '#!/bin/sh\nexec %s %q "$@"\n' "${fusho_shell_words[*]}" "${FUSHO_REPO_ROOT}/bin/fusho" >"${fusho_bin_next}"
chmod +x "${fusho_bin_next}"
mv -f "${fusho_bin_next}" "${FUSHO_BIN}"
export FUSHO_TESTS_DIR FUSHO_REPO_ROOT FUSHO_BIN

fixture_workspace() {
  local dir
  dir="$(mktemp -d "${TMPDIR:-/tmp}/fusho-test-XXXXXX")"
  mkdir -p "${dir}/config"
  printf '%s\n' "${dir}"
}

fixture_generate_ed25519() {
  local dir=$1 name=$2
  ssh-keygen -q -t ed25519 -N '' -C "${name}" -f "${dir}/${name}" </dev/null
}

fixture_generate_rsa() {
  local dir=$1 name=$2 bits=${3:-4096}
  ssh-keygen -q -t rsa -b "${bits}" -N '' -C "${name}" -f "${dir}/${name}" </dev/null
}

fixture_generate_rsa_pem() {
  local dir=$1 name=$2 bits=${3:-2048}
  ssh-keygen -q -t rsa -b "${bits}" -m PEM -N '' -C "${name}" -f "${dir}/${name}" </dev/null
}

fixture_generate_ecdsa() {
  local dir=$1 name=$2
  ssh-keygen -q -t ecdsa -b 256 -N '' -C "${name}" -f "${dir}/${name}" </dev/null
}

fixture_fingerprint() {
  local listing
  listing="$(ssh-keygen -lf "$1")"
  printf '%s\n' "${listing}" | awk '{print $2}'
}

fixture_publish_keys() {
  local served=$1 user=$2
  shift 2
  : >"${served}/${user}.keys"
  local pub
  for pub in "$@"; do
    awk '{print $1" "$2}' "${pub}" >>"${served}/${user}.keys"
  done
}

fixture_publish_empty_account() {
  local served=$1 user=$2
  : >"${served}/${user}.keys"
}

keyserver_start() {
  local served=$1
  python3 "${FUSHO_TESTS_DIR}/keyserver.py" "${served}" >"${served}/.port" 2>"${served}/.port.err" &
  KEYSERVER_PID=$!
  local waited=0
  while [[ ! -s "${served}/.port" ]]; do
    sleep 0.05
    waited=$((waited + 1))
    if [[ "${waited}" -gt 100 ]]; then
      printf 'keyserver failed to start: %s\n' "$(cat "${served}/.port.err" || true)" >&2
      return 1
    fi
  done
  KEYSERVER_PORT="$(cat "${served}/.port")"
  FUSHO_GITHUB_BASE="http://127.0.0.1:${KEYSERVER_PORT}"
  export FUSHO_GITHUB_BASE
}

keyserver_stop() {
  if [[ -n "${KEYSERVER_PID:-}" ]]; then
    kill "${KEYSERVER_PID}" 2>/dev/null || true
    wait "${KEYSERVER_PID}" 2>/dev/null || true
    KEYSERVER_PID=""
  fi
}

fusho() {
  "${FUSHO_BIN}" "$@"
}

sandbox_path_excluding() {
  local dir=$1 excluded=$2
  local tool resolved
  mkdir -p "${dir}"
  for tool in bash env curl ssh-keygen openssl awk sed grep wc tr sort cat mktemp \
    chmod rm head fold cut dirname basename uname cmp mkdir touch mv ln ls find sleep seq date age python3 gzip gunzip qrencode; do
    if [[ "${tool}" == "${excluded}" ]]; then
      continue
    fi
    resolved=$(command -v "${tool}" 2>/dev/null) || continue
    ln -sf "${resolved}" "${dir}/${tool}"
  done
  printf '%s\n' "${dir}"
}

FUSHO_TEST_VERSION="$(sed -n 's/^FUSHO_VERSION="\(.*\)"$/\1/p' "${FUSHO_REPO_ROOT}/lib/core.sh")"
export FUSHO_TEST_VERSION

fixture_tamper_body() {
  awk '
    /^-----BEGIN FUSHO MESSAGE-----$/ { started = 1; print; next }
    !started { print; next }
    /^-----END FUSHO MESSAGE-----$/ { print; next }
    body && !changed && length($0) > 20 {
      sub(/^....../, "AAAAAA")
      changed = 1
      print
      next
    }
    { print }
    /^$/ { body = 1 }
  ' "$1" >"$2"
}

fixture_corrupt_body() {
  awk '
    /^-----BEGIN FUSHO MESSAGE-----$/ { started = 1; print; next }
    !started { print; next }
    /^-----END FUSHO MESSAGE-----$/ { print; next }
    body && !changed && length($0) > 20 {
      print "!!!! not valid base64 !!!!"
      changed = 1
      next
    }
    { print }
    /^$/ { body = 1 }
  ' "$1" >"$2"
}

# shellcheck disable=SC2154
assert_status() {
  local expected=$1
  if [[ "${status}" -ne "${expected}" ]]; then
    printf 'expected exit status %s, got %s\noutput:\n%s\n' "${expected}" "${status}" "${output}" >&2
    return 1
  fi
}

assert_output_contains() {
  local needle=$1
  case "${output}" in
  *"${needle}"*) ;;
  *)
    printf 'expected output to contain: %s\nactual output:\n%s\n' "${needle}" "${output}" >&2
    return 1
    ;;
  esac
}

assert_output_lacks() {
  local needle=$1
  case "${output}" in
  *"${needle}"*)
    printf 'expected output NOT to contain: %s\nactual output:\n%s\n' "${needle}" "${output}" >&2
    return 1
    ;;
  *) ;;
  esac
}

assert_equal() {
  local actual=$1 expected=$2
  if [[ "${actual}" != "${expected}" ]]; then
    printf 'expected: %s\nactual:   %s\n' "${expected}" "${actual}" >&2
    return 1
  fi
}

assert_files_identical() {
  local left=$1 right=$2
  if ! cmp -s "${left}" "${right}"; then
    printf 'files differ: %s vs %s\n' "${left}" "${right}" >&2
    left="$(shasum -a 256 <"${left}")"
    right="$(shasum -a 256 <"${right}")"
    printf 'left  sha: %s\n' "${left%% *}" >&2
    printf 'right sha: %s\n' "${right%% *}" >&2
    return 1
  fi
}

fusho_test_call() {
  local -a shell_words
  read -r -a shell_words <<<"${FUSHO_TEST_SHELL:-sh}"
  "${shell_words[@]}" "${FUSHO_TESTS_DIR}/call.sh" "$@"
}

fusho_test_matches_golden() {
  local name="$1"
  local actual="$2"
  local os golden normalized
  os="$(uname -s)"
  golden="${FUSHO_TESTS_DIR}/golden/${name}.${os}.txt"
  normalized="${actual//"${WORK}"/WORK}"
  normalized="$(awk '
    /^-----BEGIN FUSHO MESSAGE-----$/ { block = 1; body = 0; print; next }
    /^-----END FUSHO MESSAGE-----$/ { block = 0; print; next }
    block && body { if (!shown) print "BODY"; shown = 1; next }
    block && /^$/ { body = 1; shown = 0; print; next }
    block && /^sig: / { print "sig: SIGNATURE"; next }
    { print }
  ' <<<"${normalized}")"
  normalized="$(sed -E -e 's#SHA256:[A-Za-z0-9+/]{43}#SHA256:FINGERPRINT#g' -e 's#[0-9]{10}#EPOCH#g' <<<"${normalized}")"
  if [[ "${FUSHO_TEST_RECORD:-}" == "1" ]]; then
    mkdir -p "${FUSHO_TESTS_DIR}/golden"
    printf '%s\n' "${normalized}" >"${golden}"
  fi
  diff <(printf '%s\n' "${normalized}") "${golden}"
}
