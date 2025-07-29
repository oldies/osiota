# SOPS Helper Scripts for Osiota

These scripts help you convert plain JSON config files to partially SOPS-encrypted JSON config files (encrypting only sensitive fields), and decrypt them for editing or inspection.

## Prerequisites
- [SOPS](https://github.com/getsops/sops) installed (`sops` command available)
- [age](https://github.com/FiloSottile/age), SSH, or GPG key(s) set up (see below)

## Key Setup (age, SSH, or GPG)
- **age (recommended):**
  - Generate a new key:
    ```sh
    age-keygen -o ~/.config/sops/age/keys.txt
    ```
  - Or set the `SOPS_AGE_KEY` or `SOPS_AGE_KEY_FILE` environment variable.
- **SSH:**
  - SOPS can use SSH private keys (ed25519, RSA) for decryption.
  - By default, SOPS will look for `~/.ssh/id_ed25519` or `~/.ssh/id_rsa`.
  - Or set `SOPS_AGE_SSH_PRIVATE_KEY_FILE` to specify a key.
- **GPG:**
  - SOPS will use your GPG keyring. You can specify a key with `--pgp` or via environment variables.

## Encrypting Sensitive Fields (In-Place or to Output File)

Use `sops-encrypt.sh` to encrypt only fields matching a regex (default: `password|secret|apiKey`).

```sh
# In-place encryption (recommended):
./sops-encrypt.sh osiota.json

# Or specify an output file:
./sops-encrypt.sh plain.json encrypted.json 'mySecret|token'
```
- This will encrypt only the matching fields.
- The rest of the config remains plaintext.

## Decrypting for Editing/Inspection (In-Place or to Output File)

Use `sops-decrypt.sh` to decrypt a SOPS-encrypted config file:

```sh
# In-place edit (decrypt, open in editor, re-encrypt on save):
./sops-decrypt.sh osiota.json

# Or output to a file:
./sops-decrypt.sh encrypted.json plain.json
```
- In-place edit will open your editor, decrypting on the fly, and re-encrypt on save.
- Output to file will produce a fully decrypted `plain.json` for editing or review.

## Example Workflow
1. Prepare your config as `osiota.json` (or `plain.json`).
2. Encrypt sensitive fields in place:
   ```sh
   ./sops-encrypt.sh osiota.json
   ```
3. Use `osiota.json` as your runtime config (Osiota will decrypt secrets at runtime).
4. To edit secrets, decrypt in place:
   ```sh
   ./sops-decrypt.sh osiota.json
   # edit in your editor, save to re-encrypt
   ```

## Encrypting for Multiple Recipients (Dev + Server)
- You can encrypt for multiple age, SSH, or GPG keys:
  ```sh
  sops --age <dev-public-key> --age <server-public-key> -i osiota.json
  # or with --pgp or --ssh
  ```
- This allows both you and the server/container to decrypt the config.

## Host-Specific Key Setup (Docker Example)

**1. Generate a key for the container/server:**
```sh
age-keygen -o ./docker-age.key
```

**2. Build your Docker image with SOPS and age installed.**

**3. Mount the key and set the environment variable:**
```sh
docker run -v $(pwd)/osiota.json:/app/osiota.json:ro \
           -v $(pwd)/docker-age.key:/run/secrets/age.key:ro \
           -e SOPS_AGE_KEY_FILE=/run/secrets/age.key \
           my-osiota-image
```

- Osiota will use the key at `/run/secrets/age.key` to decrypt secrets at runtime.
- You can also use SSH or GPG keys similarly (see SOPS docs).

## Notes
- You can adjust the regex to match any field names you want to encrypt.
- The SOPS metadata will be stored in the `sops` key at the root of the JSON file.
- Only the values matching the regex will be encrypted; all other config remains readable.
- For more, see the [SOPS documentation](https://github.com/getsops/sops) and [sops-age](https://www.npmjs.com/package/sops-age). 