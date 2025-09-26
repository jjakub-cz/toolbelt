#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'EOF'
http-security-txt-check.sh
Validate a site's /.well-known/security.txt according to RFC 9116.

USAGE:
  http-security-txt-check.sh <domain>

EXAMPLE:
  http-security-txt-check.sh example.com

NOTES:
  - Fetches https://<domain>/.well-known/security.txt
  - Checks HTTP status, Content-Type, presence of "Contact:", character set, and duplicate fields.
EOF
}

DOMAIN="${1:-}"

if [[ "$DOMAIN" == "-h" || "$DOMAIN" == "--help" ]]; then
  show_help
  exit 0
fi

if [[ -z "$DOMAIN" ]]; then
  echo "Usage: $0 <domain>"
  echo "Try '$0 --help' for more information."
  exit 1
fi

URL="https://${DOMAIN}/.well-known/security.txt"

echo "== Checking security.txt at: ${URL}"

# Fetch headers + body
HTTP_RESPONSE=$(mktemp)
BODY=$(mktemp)
if ! curl -sS -D "$HTTP_RESPONSE" -o "$BODY" "$URL"; then
  echo "[ERROR] Cannot download the file."
  exit 1
fi

STATUS=$(head -n 1 "$HTTP_RESPONSE" | awk '{print $2}')
CONTENT_TYPE=$(grep -i "^content-type:" "$HTTP_RESPONSE" | awk '{print $2}' | tr -d '\r')

# --- HTTP status code check
if [[ "$STATUS" != "200" ]]; then
  echo "[ERROR] HTTP status is $STATUS (expected 200)"
  echo
  cat "$HTTP_RESPONSE"
  exit 1
else
  echo "[OK] HTTP status 200 OK"
fi

# --- Content-Type check
if [[ "$CONTENT_TYPE" != "text/plain" && "$CONTENT_TYPE" != "text/plain;"* ]]; then
  echo "[ERROR] Content-Type is '$CONTENT_TYPE' (expected text/plain)"
  exit 1
else
  echo "[OK] Content-Type = $CONTENT_TYPE"
fi

# --- Content check
if ! grep -qi "^Contact:" "$BODY"; then
  echo "[ERROR] Missing required field: Contact"
  exit 1
else
  echo "[OK] Contains required field: Contact"
fi

# --- Character set check (ignores LF as line separator)
INVALID_CHARS=$(perl -CS -ne '
  use utf8;
  while (/([^\x09\x20\x21-\x7E\x{80}-\x{10FFFF}\x0A])/g) {
    printf "0x%X ", ord($1);
  }
' "$BODY")

if [[ -n "$INVALID_CHARS" ]]; then
  echo "[ERROR] Invalid characters found: $INVALID_CHARS"
  exit 1
else
  echo "[OK] All characters are within the allowed range"
fi

# --- Duplicate disallowed fields check
FIELDS=$(grep -E '^[A-Za-z-]+:' "$BODY" | cut -d: -f1 | tr '[:upper:]' '[:lower:]')
DUPLICATES=$(echo "$FIELDS" | sort | uniq -d)
if [[ -n "$DUPLICATES" ]]; then
  echo "[ERROR] Duplicate field(s) found: $DUPLICATES"
  exit 1
else
  echo "[OK] No duplicate fields"
fi

echo "[PASS] security.txt on $DOMAIN appears valid per RFC 9116"

echo
echo "== Parsed fields from security.txt:"
grep -E '^[A-Za-z-]+:' "$BODY" | while IFS= read -r line; do
  key=$(echo "$line" | cut -d: -f1)
  value=$(echo "$line" | cut -d: -f2- | sed 's/^[ \t]*//')
  printf "  %-20s %s\n" "$key:" "$value"
done

echo
echo "== Full security.txt content:"
echo "----------------------------------------"
cat "$BODY"
echo "----------------------------------------"
