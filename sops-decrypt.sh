#!/bin/sh
# Usage:
#   ./sops-decrypt.sh <file.json> [output.json]
#   If only <file.json> is given, decrypt in place (open in editor and re-encrypt on save).
#   If <output.json> is given, write decrypted output to that file.

set -e

if [ $# -lt 1 ]; then
  echo "Usage: $0 <file.json> [output.json]"
  exit 1
fi

ENCRYPTED_FILE="$1"

if [ $# -eq 1 ]; then
  # In-place edit (decrypt, open in editor, re-encrypt on save)
  sops -i "$ENCRYPTED_FILE"
  if [ $? -eq 0 ]; then
    echo "Edited in place: $ENCRYPTED_FILE (decrypted in editor, re-encrypted on save)"
  else
    echo "Decryption/edit failed!"
    exit 2
  fi
else
  PLAIN_FILE="$2"
  sops --decrypt "$ENCRYPTED_FILE" > "$PLAIN_FILE"
  if [ $? -eq 0 ]; then
    echo "Decrypted $ENCRYPTED_FILE -> $PLAIN_FILE"
  else
    echo "Decryption failed!"
    exit 2
  fi
fi 