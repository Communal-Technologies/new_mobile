#!/usr/bin/env bash
#
# Compares the SPKI pins in CertPinning.pinsByHost against the certificates
# the API hosts are serving right now.
#
# Exit codes: 0 = every pinned host matches, 1 = drift, 2 = could not check.

set -uo pipefail

SOURCE="${1:-lib/data/datasources/remote/dio/cert_pinning.dart}"

if [[ ! -f "$SOURCE" ]]; then
  echo "cert-pins: cannot read $SOURCE" >&2
  exit 2
fi

live_pin() {
  local host="$1"
  echo \
    | openssl s_client -servername "$host" -connect "$host:443" 2>/dev/null \
    | openssl x509 -pubkey -noout 2>/dev/null \
    | openssl pkey -pubin -outform DER 2>/dev/null \
    | openssl dgst -sha256 -binary 2>/dev/null \
    | base64
}

ROWS=()
host=""
while IFS= read -r line; do
  if [[ "$line" =~ ^[[:space:]]*\'([^\']+)\'[[:space:]]*: ]]; then
    host="${BASH_REMATCH[1]}"
    continue
  fi
  if [[ -n "$host" && "$line" =~ \'([A-Za-z0-9+/=]{40,})\' ]]; then
    ROWS+=("$host"$'\t'"${BASH_REMATCH[1]}")
  fi
done < <(sed -n '/pinsByHost/,/^  };/p' "$SOURCE")

if [[ ${#ROWS[@]} -eq 0 ]]; then
  echo "cert-pins: no pins configured — nothing to check."
  exit 0
fi

declare -A PINNED
for row in "${ROWS[@]}"; do
  host="${row%%$'\t'*}"
  pin="${row##*$'\t'}"
  PINNED["$host"]+="$pin "
done

status=0
for host in "${!PINNED[@]}"; do
  live="$(live_pin "$host")"
  if [[ -z "$live" ]]; then
    echo "cert-pins: $host — could not fetch certificate (host unreachable?)" >&2
    status=2
    continue
  fi
  if [[ " ${PINNED[$host]}" == *" $live "* ]]; then
    echo "cert-pins: $host OK ($live)"
  else
    echo "cert-pins: $host DRIFTED" >&2
    echo "    pinned: ${PINNED[$host]}" >&2
    echo "    live:   $live" >&2
    [[ $status -eq 0 ]] && status=1
  fi
done

exit $status
