#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'EOF'
Usage:
  fconcat.sh [-o OUTPUT] [-i name1,name2,...] [PATH]

Description:
  Recursively traverses PATH (default ".") and merges the content of all files
  into OUTPUT (default "snapshot.txt"). For each file it prints the relative
  path followed by its content.

Parameters:
  -h|--help    this help
  -i|--ignore  dir/files to ignore (recursively)
  -o|--output  output file

Examples:
  fconcat.sh
  fconcat.sh -o dump.txt -i .git,node_modules,dist src/
EOF
}

# Default values
ROOT="."
OUTFILE="snapshot.txt"
IGNORE_CSV=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o|--output)
      OUTFILE="${2:?missing value for -o/--output}"; shift 2;;
    -i|--ignore)
      IGNORE_CSV="${2:-}"; shift 2;;
    -h|--help)
      show_help; exit 0;;
    --) shift; break;;
    -*)
      echo "Unknown option: $1" >&2; show_help; exit 1;;
    *)
      ROOT="$1"; shift;;
  esac
done

# Normalize ROOT (remove trailing /)
ROOT="${ROOT%/}"

# Split ignore list into array
IFS=',' read -r -a IGNORE_ARR <<< "${IGNORE_CSV}"

# Always ignore the output file itself (basename)
OUT_BASENAME="$(basename -- "$OUTFILE")"
IGNORE_ARR+=("$OUT_BASENAME")

# Helper: return 0 if file should be ignored
should_ignore() {
  local rel="$1"
  local base
  base="$(basename -- "$rel")"

  for name in "${IGNORE_ARR[@]}"; do
    [[ -z "$name" ]] && continue
    # Ignore exact file basename match
    if [[ "$base" == "$name" ]]; then
      return 0
    fi
    # Ignore if any part of the path matches (directory or file)
    if [[ "/$rel/" == *"/$name/"* ]]; then
      return 0
    fi
  done

  return 1
}

# Initialize (overwrite) output file
: > "$OUTFILE"

# Walk all regular files
while IFS= read -r -d '' f; do
  # Get relative path from ROOT
  rel="${f#$ROOT/}"
  # Skip output file itself
  if [[ "$rel" == "$OUT_BASENAME" ]]; then
    continue
  fi
  # Apply ignore logic
  if should_ignore "$rel"; then
    continue
  fi

  # File size (bytes)
  size_bytes=$(wc -c < "$f" || echo 0)

  {
    printf '===== FILE: %s | SIZE: %s bytes =====\n' "$rel" "$size_bytes"
    # Dump file content (binary files will also be included as raw bytes)
    cat -- "$f" || true
    # Ensure trailing newline
    [[ $(tail -c1 "$f" 2>/dev/null | wc -c) -eq 1 ]] || printf '\n'
    printf '\n===== END FILE: %s =====\n\n' "$rel"
  } >> "$OUTFILE"

done < <(find "$ROOT" -type f -print0 | sort -z)

echo "Done. Output file: $OUTFILE"
