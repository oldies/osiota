#!/bin/sh
# Usage:
#   ./sops-encrypt.sh <file.json> [output.json] [regex]
#   If only <file.json> is given, encrypt in place.
#   If <output.json> is given, write to that file.
#   Default regex: password|secret|apiKey

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 <file.json> [output.json] [regex]"
  exit 1
fi

PLAIN_FILE="$1"
REGEX="${3:-password|secret|apiKey}"

# Check for age key
AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"
if [ ! -f "$AGE_KEY_FILE" ]; then
  echo "ERROR: No age key found at $AGE_KEY_FILE."
  echo "Generate one with: age-keygen -o $AGE_KEY_FILE"
  echo "Or set SOPS_AGE_KEY_FILE to your key file."
  exit 2
fi

if [ $# -eq 1 ]; then
  # In-place encryption
  sops --encrypt --encrypted-regex "$REGEX" -i "$PLAIN_FILE"
  if [ $? -eq 0 ]; then
    echo "Encrypted in place: $PLAIN_FILE (fields: $REGEX)"
  else
    echo "Encryption failed!"
    exit 2
  fi
else
  ENCRYPTED_FILE="$2"
  sops --encrypt --encrypted-regex "$REGEX" "$PLAIN_FILE" > "$ENCRYPTED_FILE"
  if [ $? -eq 0 ]; then
    echo "Encrypted $PLAIN_FILE -> $ENCRYPTED_FILE (fields: $REGEX)"
  else
    echo "Encryption failed!"
    exit 2
  fi
fi 