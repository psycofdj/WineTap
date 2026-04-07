#!/bin/bash
set -euo pipefail

VAULT="${1:-$HOME/pCloudDrive/Minouches/keepaasxc/vault.kdbx}"
ENTRY="winetap"
SECRETS_DIR="$HOME/winetap-build"
rm -rf "$SECRETS_DIR"
mkdir -p "$SECRETS_DIR"
KEYSTORE_PATH="$SECRETS_DIR/upload-keystore.jks"

if [[ ! -f "$VAULT" ]]; then
  echo "ERROR: vault not found at $VAULT" >&2
  exit 1
fi

if ! command -v keepassxc.cli &>/dev/null; then
  echo "ERROR: keepassxc.cli not found in PATH" >&2
  exit 1
fi

read -s -p "Master password: " MASTER_PASSWORD
echo

KEY_FILE="$SECRETS_DIR/key"
echo -n "$MASTER_PASSWORD" > "$KEY_FILE"
unset MASTER_PASSWORD

KP_AUTH="--key-file $KEY_FILE --no-password"

# Fetch secrets from KeePassXC
ANDROID_KEY_ALIAS=$(keepassxc.cli show -s -a android_key_alias $KP_AUTH "$VAULT" "$ENTRY")
ANDROID_KEY_PASSWORD=$(keepassxc.cli show -s -a android_password $KP_AUTH "$VAULT" "$ENTRY")
ANDROID_STORE_PASSWORD="$ANDROID_KEY_PASSWORD"

# Export keystore attachment
keepassxc.cli attachment-export $KP_AUTH "$VAULT" "$ENTRY" "upload-keystore.jks" "$KEYSTORE_PATH"
echo "Secrets loaded, keystore written to $KEYSTORE_PATH"

# Build Android App Bundle
export ANDROID_KEY_ALIAS
export ANDROID_KEY_PASSWORD
export ANDROID_STORE_PASSWORD
export ANDROID_KEYSTORE_PATH="$KEYSTORE_PATH"

cd "$(dirname "$0")/../mobile"

VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: *//;s/+.*//')
SHA=$(git rev-parse --short HEAD)
BUILD_NAME="${VERSION}-${SHA}-dev"

flutter pub get
flutter build appbundle --release --build-name="$BUILD_NAME"

echo "Build complete: build/app/outputs/bundle/release/app-release.aab"

# Cleanup
rm -rf "$SECRETS_DIR"
