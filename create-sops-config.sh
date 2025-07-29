#!/bin/bash

# Function to get default GPG key from pass
get_default_gpg_key() {
    local key_from_pass
    local key_from_git
    if command -v pass &> /dev/null; then
        key_from_pass=$(cat ~/.password-store/.gpg-id)
        #$(pass git config user.signingkey 2>/dev/null)
    fi
    key_from_git=$(git config --global user.signingkey 2>/dev/null)
    if [ -z "$key_from_pass" ] && [ -z "$key_from_git" ]; then
        echo "Listing available GPG keys:" >&2
        gpg --list-secret-keys --keyid-format=long
        read -p "Enter the GPG key fingerprint or long key ID: " key_from_user
        if [ -z "$key_from_user" ]; then
            echo "No GPG key selected. Exiting." >&2
            return 1
        fi
        echo "$key_from_user"
        return 0
    fi
    echo "${key_from_pass:-$key_from_git}"
}

# Function to get SSH public key
get_ssh_key() {
    local ssh_dir="$HOME/.ssh"
    local keys=()
    for keyfile in "$ssh_dir"/*.pub; do
        [ -e "$keyfile" ] || continue
        keys+=("$keyfile")
    done
    if [ ${#keys[@]} -eq 0 ]; then
        echo "No SSH public keys found in $ssh_dir. Please generate one with ssh-keygen." >&2
        return 1
    fi
    echo "Available SSH public keys:"
    for i in "${!keys[@]}"; do
        echo "$((i+1)). ${keys[$i]}"
    done
    read -p "Select SSH key (1-${#keys[@]}), or paste a public key: " idx
    if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -ge 1 ] && [ "$idx" -le ${#keys[@]} ]; then
        cat "${keys[$((idx-1))]}"
    else
        # Assume user pasted a key
        echo "$idx"
    fi
}

# Function to get age public key
get_age_key() {
    local age_file="$HOME/.config/sops/age/keys.txt"
    if [ ! -f "$age_file" ]; then
        echo "No age key file found at $age_file. Generate one with: age-keygen -o $age_file" >&2
        read -p "Paste your age public key (starts with 'age1'): " age_pub
        if [ -z "$age_pub" ]; then
            echo "No age public key provided. Exiting." >&2
            return 1
        fi
        echo "$age_pub"
        return 0
    fi
    local pubkeys=( $(grep '^# public key:' "$age_file" | awk '{print $4}') )
    if [ ${#pubkeys[@]} -eq 0 ]; then
        echo "No public keys found in $age_file. Please check the file." >&2
        return 1
    fi
    echo "Available age public keys:"
    for i in "${!pubkeys[@]}"; do
        echo "$((i+1)). ${pubkeys[$i]}"
    done
    read -p "Select age key (1-${#pubkeys[@]}), or paste a public key: " idx
    if [[ "$idx" =~ ^[0-9]+$ ]] && [ "$idx" -ge 1 ] && [ "$idx" -le ${#pubkeys[@]} ]; then
        echo "${pubkeys[$((idx-1))]}"
    else
        # Assume user pasted a key
        echo "$idx"
    fi
}

# Main script
main() {
    # Check if .sops.yaml already exists
    if [ -f ".sops.yaml" ]; then
        read -p ".sops.yaml already exists. Overwrite? (y/n) " overwrite
        if [[ "$overwrite" != "y" ]]; then
            echo "Aborted."
            exit 1
        fi
    fi

    echo "Which key type do you want to use for SOPS encryption?"
    echo "1) GPG (PGP)"
    echo "2) SSH public key"
    echo "3) age public key"
    read -p "Select (1-3): " keytype

    case "$keytype" in
        1)
            if ! command -v gpg &> /dev/null; then
                echo "GPG is not installed. Please install GPG first." >&2
                exit 1
            fi
            gpg_key=$(get_default_gpg_key)
            if [ $? -ne 0 ]; then exit 1; fi
            #if ! gpg --list-secret-keys "$gpg_key" &> /dev/null; then
            #    echo "Invalid or non-existent GPG key: $gpg_key" >&2
            #    exit 1
            #fi
            cat > .sops.yaml << EOF
# SOPS configuration file
keys:
  - &my-gpg-key ${gpg_key}

creation_rules:
  - path_regex: .*\\.json
a    key_groups:
    - pgp:
      - *my-gpg-key
EOF
            echo "Created .sops.yaml with GPG key: $gpg_key"
            ;;
        2)
            ssh_key=$(get_ssh_key)
            if [ $? -ne 0 ]; then exit 1; fi
            cat > .sops.yaml << EOF
# SOPS configuration file
keys:
  - &my-ssh-key ${ssh_key}

creation_rules:
  - path_regex: .*\\.json
a    key_groups:
    - pgp:
      - *my-ssh-key
EOF
            echo "Created .sops.yaml with SSH key."
            ;;
        3)
            age_key=$(get_age_key)
            if [ $? -ne 0 ]; then exit 1; fi
            cat > .sops.yaml << EOF
# SOPS configuration file
creation_rules:
  - path_regex: .*\\.json$
    age: ${age_key}
EOF
            echo "Created .sops.yaml with age key: $age_key"
            ;;
        *)
            echo "Invalid selection. Exiting."
            exit 1
            ;;
    esac
}

main

