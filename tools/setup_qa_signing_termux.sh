#!/usr/bin/env bash
# TJ-44S stable signing enrollment. Run from Termux as the GitHub repo owner.
# Never echo passwords, never upload private keys to source control.
set -Eeuo pipefail
umask 077

repo="cube23games/Balloon_Burst"
alias_name="balloon_qa"
key_dir="$HOME/.local/share/balloon-burst"
keystore="$key_dir/qa-signing.p12"

for required in gh keytool base64; do
  if ! command -v "$required" >/dev/null 2>&1; then
    printf 'ERROR: %s missing. Install with: pkg install openjdk-17 gh coreutils\n' "$required" >&2
    exit 1
  fi
done

if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  printf 'ERROR: GitHub CLI is not authenticated. Run: gh auth login -h github.com\n' >&2
  exit 1
fi
if ! gh repo view "$repo" --json name --jq .name >/dev/null 2>&1; then
  printf 'ERROR: Cannot access %s using the active GitHub login.\n' "$repo" >&2
  exit 1
fi

mkdir -p "$key_dir"
if [[ ! -f "$keystore" ]]; then
  # Never generate a replacement when GitHub already has an existing key:
  # replacement would silently break Android update compatibility.
  if gh secret list -R "$repo" | grep -q '^BB_SIGNING_KEYSTORE_B64[[:space:]]'; then
    printf 'STOP: GitHub already has a signing key, but local keystore is absent.\n' >&2
    printf 'Restore the original QA keystore backup before proceeding.\n' >&2
    exit 1
  fi
  printf 'Creating first long-term QA signing key for %s\n' "$repo"
  printf 'Choose a strong password (at least 16 characters). Input is hidden.\n'
  IFS= read -r -s -p 'New signing password: ' password
  printf '\n'
  IFS= read -r -s -p 'Confirm signing password: ' password_confirm
  printf '\n'
  if [[ $(printf '%s' "$password" | wc -c) -lt 16 || "$password" != "$password_confirm" ]]; then
    unset password password_confirm
    printf 'STOP: Passwords did not match or were too short.\n' >&2
    exit 1
  fi
  unset password_confirm
  keytool -genkeypair -noprompt \
    -alias "$alias_name" \
    -keystore "$keystore" \
    -storetype PKCS12 \
    -keyalg RSA -keysize 3072 -validity 10000 \
    -dname 'CN=Balloon Burst QA, OU=TapJunkie Games, O=Cube23, C=US' \
    -storepass "$password" -keypass "$password" >/dev/null 2>&1
  chmod 600 "$keystore"
  printf 'Created and secured: %s\n' "$keystore"
else
  printf 'Reusing existing signing key: %s\n' "$keystore"
  IFS= read -r -s -p 'Existing signing password: ' password
  printf '\n'
fi

if ! keytool -list -storetype PKCS12 \
  -keystore "$keystore" -alias "$alias_name" \
  -storepass "$password" >/dev/null 2>&1; then
  unset password
  printf 'STOP: Wrong password, alias, or invalid keystore. No secrets uploaded.\n' >&2
  exit 1
fi

printf 'Uploading encrypted signing material directly to GitHub Actions secrets...\n'
base64 "$keystore" | tr -d '\n' | gh secret set BB_SIGNING_KEYSTORE_B64 -R "$repo"
printf '%s' "$password" | gh secret set BB_SIGNING_STORE_PASSWORD -R "$repo"
printf '%s' "$password" | gh secret set BB_SIGNING_KEY_PASSWORD -R "$repo"
printf '%s' "$alias_name" | gh secret set BB_SIGNING_KEY_ALIAS -R "$repo"
unset password

printf '\nThe four repository secret names (no values) should now appear below:\n'
gh secret list -R "$repo" | grep '^BB_SIGNING_' || true
printf '\nIMPORTANT: Back up %s securely OFF this phone.\n' "$keystore"
printf 'Keep the password separately. NEVER upload either one to ChatGPT or the public repository.\n'
printf 'Without the original keystore and password, future updates may require uninstalling.\n'
