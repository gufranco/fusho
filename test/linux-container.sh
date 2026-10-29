#!/bin/sh
set -eu

repo="$(cd "$(dirname "$0")/.." && pwd)"
image="${FUSHO_TEST_IMAGE:-ubuntu:26.04}"

docker run --rm \
  -v "${repo}:/repo" \
  -w /repo \
  -e FUSHO_TEST_SHELLS="${FUSHO_TEST_SHELLS:-}" \
  -e FUSHO_TEST_RECORD="${FUSHO_TEST_RECORD:-}" \
  "${image}" \
  sh -c '
    set -eu
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq >/dev/null
    apt-get install -y -qq --no-install-recommends \
      bats dash zsh mksh mandoc file python3 ca-certificates age openssh-client openssl curl git qrencode >/dev/null
    exec "$@"
  ' sh "$@"
