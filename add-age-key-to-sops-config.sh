#!/bin/bash

set -e

SOPS_CONFIG=".sops.yaml"
AGE_DIR="$HOME/.config/sops/age"
AGE_KEY_FILE="$AGE_DIR/keys.txt"

# Function to generate a new age key and return the public key
generate_age_key() {
    mkdir -p "$AGE_DIR"
    local keyfile
    keyfile=$(mktemp)
    age-keygen > "$keyfile"
    local pubkey
    pubkey=$(awk '/^# public key:/ {print $4}' "$keyfile")
    cat "$keyfile" >> "$AGE_KEY_FILE"
    rm "$keyfile"
    echo "$pubkey"
}

# Get age public key from argument, or generate a new one
if [ -n "$1" ]; then
    AGE_KEY="$1"
else
    echo "No age public key provided. Generating a new one..."
    AGE_KEY=$(generate_age_key)
    echo "Generated new age public key: $AGE_KEY"
fi

if [[ ! "$AGE_KEY" =~ ^age1[0-9a-z]+$ ]]; then
    echo "Invalid age public key. It should start with 'age1'."
    exit 1
fi

# If .sops.yaml does not exist, create it
if [ ! -f "$SOPS_CONFIG" ]; then
    cat > "$SOPS_CONFIG" <<EOF
creation_rules:
  - path_regex: \.json$
    age: $AGE_KEY
EOF
    echo "Created $SOPS_CONFIG with age key: $AGE_KEY"
    exit 0
fi

# If .sops.yaml exists, update or add the age key
# Use yq if available for robust YAML editing, else fallback to sed/awk
if command -v yq &> /dev/null; then
    # Use yq to update or add the age key in the first rule with .json path_regex
    yq eval \
      '(.creation_rules[] | select(.path_regex == ".*\\.json$" or .path_regex == "\\.json$")) as $rule | \
        if $rule then
          .creation_rules[] |= (select(.path_regex == ".*\\.json$" or .path_regex == "\\.json$") | .age = ((.age // "") + "," + env(AGE_KEY) | ltrimstr(",")) // .)
        else
          .creation_rules += [{"path_regex": ".json$", "age": env(AGE_KEY)}]
        end' \
      "$SOPS_CONFIG" > "$SOPS_CONFIG.tmp" && mv "$SOPS_CONFIG.tmp" "$SOPS_CONFIG"
    echo "Added $AGE_KEY to .sops.yaml (using yq)"
else
    # Fallback: crude sed/awk update (assumes only one rule for .json files)
    if grep -q '^\s*age:' "$SOPS_CONFIG"; then
        sed -i.bak "/^\s*age:/ { s/:\s*\(.*\)/: \1,$AGE_KEY/ }" "$SOPS_CONFIG"
        echo "Added $AGE_KEY to existing age key(s) in $SOPS_CONFIG"
    else
        # Add a new rule, preserving existing content
        cat >> "$SOPS_CONFIG" <<EOF
creation_rules:
  - path_regex: \.json$
    age: $AGE_KEY
EOF
        echo "Appended new age rule to $SOPS_CONFIG with key: $AGE_KEY"
    fi
fi 