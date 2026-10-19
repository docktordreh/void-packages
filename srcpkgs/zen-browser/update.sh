#!/bin/bash

set -euo pipefail

REPO="zen-browser/desktop"
TPL="srcpkgs/zen-browser/template"

echo "Checking for zen-browser updates..."

LATEST_VERSION=$(gh api repos/$REPO/releases/latest --jq .tag_name | sed 's/^v//')
CURRENT_VERSION=$(grep '^version=' "$TPL" | cut -d= -f2)

printf "Latest version is: %s\nLatest built version is: %s\n" "${LATEST_VERSION}" "${CURRENT_VERSION}"
if [ "$LATEST_VERSION" != "$CURRENT_VERSION" ]; then
    echo "Update found: $CURRENT_VERSION -> $LATEST_VERSION"
fi

URL_X86="https://github.com/$REPO/releases/download/${LATEST_VERSION}/zen.linux-x86_64.tar.xz"
URL_AARCH64="https://github.com/$REPO/releases/download/${LATEST_VERSION}/zen.linux-aarch64.tar.xz"

echo "Calculating checksums..."
CHK_X86=$(curl --fail --location --silent --show-error --retry 3 "$URL_X86" | sha256sum | awk '{print $1}')
CHK_AARCH64=$(curl --fail --location --silent --show-error --retry 3 "$URL_AARCH64" | sha256sum | awk '{print $1}')

if [ -z "$CHK_X86" ] || [ -z "$CHK_AARCH64" ]; then
    echo "Error: Failed to fetch checksums."
    exit 1
fi

echo "Checksums: x86_64=$CHK_X86 aarch64=$CHK_AARCH64"

CURRENT_AARCH64=$(sed -n '/aarch64\*)/,/;;/ s/.*checksum="\([0-9a-f]*\)"/\1/p' "$TPL")
CURRENT_X86=$(sed -n '/x86_64\*)/,/;;/ s/.*checksum="\([0-9a-f]*\)"/\1/p' "$TPL")
CURRENT_REVISION=$(sed -n 's/^revision=//p' "$TPL")

if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ] \
    && [ "$CHK_AARCH64" = "$CURRENT_AARCH64" ] \
    && [ "$CHK_X86" = "$CURRENT_X86" ]; then
    echo "No update required. Current version: $CURRENT_VERSION"
    exit 0
fi

if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
    revision=$((CURRENT_REVISION + 1))
else
    revision=1
fi

# The first checksum is for aarch64; the second is for x86_64.
awk -v version="$LATEST_VERSION" -v revision="$revision" \
  -v chk_aarch="$CHK_AARCH64" -v chk_x86="$CHK_X86" '
  /^version=/ { print "version=" version; next }
  /^revision=/ { print "revision=" revision; next }
  /^[[:space:]]*checksum=/ && n_checksums == 0 { sub(/checksum=.*/, "checksum=\"" chk_aarch "\""); n_checksums++ }
  /^[[:space:]]*checksum=/ && n_checksums == 1 { sub(/checksum=.*/, "checksum=\"" chk_x86 "\""); n_checksums++ }
  { print }
' "$TPL" > "${TPL}.tmp" && mv "${TPL}.tmp" "$TPL"

if [ -n "${GITHUB_ENV:-}" ]; then
    echo "NEW_VERSION=${LATEST_VERSION}_${revision}" >> "$GITHUB_ENV"
fi
echo "Updated zen-browser to ${LATEST_VERSION}_${revision}"
