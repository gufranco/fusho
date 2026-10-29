#!/bin/sh

# shellcheck source=SCRIPTDIR/state.sh
. "${FUSHO_LIB:?}/state.sh"

fusho_emit_armor() {
  fusho_ea_alg="$1"
  fusho_ea_tofile="$2"
  fusho_ea_selected_fps="$3"
  fusho_ea_ciphertext="$4"
  fusho_ea_from="${5:-}"
  fusho_ea_signature="${6:-}"
  fusho_ea_encoding="${7:-}"
  fusho_ea_expires="${8:-}"
  fusho_ea_fingerprint=""
  fusho_ea_recipient=""
  printf '%s\n' "${FUSHO_ARMOR_BEGIN}"
  printf 'v: %s\n' "${FUSHO_FORMAT_VERSION}"
  printf 'alg: %s\n' "${fusho_ea_alg}"
  if [ -n "${fusho_ea_from}" ]; then
    printf 'from: %s\n' "${fusho_ea_from}"
  fi
  if [ -n "${fusho_ea_signature}" ]; then
    printf 'sig: %s\n' "${fusho_ea_signature}"
  fi
  if [ -n "${fusho_ea_encoding}" ]; then
    printf 'enc: %s\n' "${fusho_ea_encoding}"
  fi
  if [ -n "${fusho_ea_expires}" ]; then
    printf 'exp: %s\n' "${fusho_ea_expires}"
  fi
  while IFS= read -r fusho_ea_recipient; do
    printf 'to: %s\n' "${fusho_ea_recipient}"
  done <"${fusho_ea_tofile}"
  while IFS= read -r fusho_ea_fingerprint; do
    printf 'key: %s\n' "${fusho_ea_fingerprint}"
  done <"${fusho_ea_selected_fps}"
  printf '\n'
  openssl base64 -A -in "${fusho_ea_ciphertext}" | fold -w 64
  printf '\n%s\n' "${FUSHO_ARMOR_END}"
}

# shellcheck disable=SC2016
FUSHO_AWK_FIELD='BEGIN{p=want": "} /^-----BEGIN (FUSHO|OSM) MESSAGE-----$/{s=1;b=0;next} !s{next} /^-----END (FUSHO|OSM) MESSAGE-----$/{exit} /^$/{b=1} !b&&index($0,p)==1{print substr($0,length(p)+1)}'
FUSHO_AWK_BODY='/^-----BEGIN (FUSHO|OSM) MESSAGE-----$/{s=1;next} !s{next} /^-----END (FUSHO|OSM) MESSAGE-----$/{exit} b{print} /^$/{b=1}'

fusho_armor_field() {
  awk -v want="$2" "${FUSHO_AWK_FIELD}" "$1"
}

fusho_armor_body() {
  awk "${FUSHO_AWK_BODY}" "$1"
}

fusho_require_armor() {
  fusho_ra_file="$1"
  if ! grep -Eq -- '^-----BEGIN (FUSHO|OSM) MESSAGE-----$' "${fusho_ra_file}"; then
    fusho_die "no fusho message found in the input. copy the whole block, including the ${FUSHO_ARMOR_BEGIN} and ${FUSHO_ARMOR_END} lines, and try again."
  fi
  if ! grep -Eq -- '^-----END (FUSHO|OSM) MESSAGE-----$' "${fusho_ra_file}"; then
    fusho_die "the fusho message is truncated. the closing ${FUSHO_ARMOR_END} line is missing."
  fi
}

fusho_json_array() {
  awk 'BEGIN{printf "["} {gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); printf "%s\"%s\"", (NR>1 ? "," : ""), $0} END{printf "]"}' "$1"
}

fusho_emit_json() {
  fusho_ej_alg="$1"
  fusho_ej_tofile="$2"
  fusho_ej_selected_fps="$3"
  fusho_ej_armor="$4"
  fusho_ej_to=$(fusho_json_array "${fusho_ej_tofile}")
  fusho_ej_keys=$(fusho_json_array "${fusho_ej_selected_fps}")
  fusho_ej_body=$(awk '{gsub(/\\/,"\\\\"); gsub(/"/,"\\\""); printf "%s\\n", $0}' "${fusho_ej_armor}")
  printf '{"version":"%s","alg":"%s","to":%s,"keys":%s,"armor":"%s"}\n' \
    "${FUSHO_FORMAT_VERSION}" "${fusho_ej_alg}" "${fusho_ej_to}" "${fusho_ej_keys}" "${fusho_ej_body}"
}

fusho_parse_duration() {
  fusho_pd_value="$1"
  fusho_pd_number=""
  fusho_pd_unit=""
  fusho_pd_number=$(printf '%s' "${fusho_pd_value}" | sed -n 's/^\([0-9][0-9]*\).*$/\1/p')
  fusho_pd_unit=$(printf '%s' "${fusho_pd_value}" | sed -n 's/^[0-9][0-9]*\(.*\)$/\1/p')
  if [ -z "${fusho_pd_number}" ]; then
    fusho_die "cannot read '${fusho_pd_value}' as a duration. use forms like 30m, 6h or 7d."
  fi
  case "${fusho_pd_unit}" in
  "" | s) printf '%s\n' "${fusho_pd_number}" ;;
  m) printf '%s\n' "$((fusho_pd_number * 60))" ;;
  h) printf '%s\n' "$((fusho_pd_number * 3600))" ;;
  d) printf '%s\n' "$((fusho_pd_number * 86400))" ;;
  *) fusho_die "unknown duration unit '${fusho_pd_unit}'. use s, m, h or d." ;;
  esac
}

fusho_expiry_stamp() {
  fusho_es_seconds=""
  fusho_es_seconds=$(fusho_parse_duration "$1") || exit 1
  fusho_es_now=$(date -u +%s)
  printf '%s\n' "$((fusho_es_now + fusho_es_seconds))"
}

fusho_format_stamp() {
  date -u -r "$1" '+%Y-%m-%d %H:%M UTC' 2>/dev/null && return 0
  date -u -d "@$1" '+%Y-%m-%d %H:%M UTC' 2>/dev/null && return 0
  printf '%s\n' "$1"
}

fusho_check_expiry() {
  fusho_ce_stamp="$1"
  fusho_ce_ignore="$2"
  fusho_ce_now=""
  if [ -z "${fusho_ce_stamp}" ]; then
    return 0
  fi
  fusho_ce_now=$(date -u +%s)
  if [ "${fusho_ce_now}" -le "${fusho_ce_stamp}" ]; then
    return 0
  fi
  if [ "${fusho_ce_ignore}" -eq 1 ]; then
    fusho_warn "warning: this message expired, opening it anyway because --ignore-expiry was given."
    return 0
  fi
  fusho_ce_until=$(fusho_format_stamp "${fusho_ce_stamp}")
  fusho_die "this message expired. the sender marked it valid until ${fusho_ce_until}. re-run with --ignore-expiry to open it regardless."
}

fusho_banner_enabled() {
  case "${FUSHO_BANNER}" in
  0 | no | off | false) return 1 ;;
  *) return 0 ;;
  esac
}

fusho_emit_banner() {
  cat <<'BANNER'
This is an encrypted message. Only the intended recipient can read it.
To open it, install fusho and pipe this whole block into it:

  brew install gufranco/tap/fusho
  pbpaste | fusho read

What it is: https://github.com/gufranco/fusho
BANNER
}
