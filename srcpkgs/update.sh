#!/bin/bash

set -euo pipefail

REPO="zen-browser/desktop"
TPL="srcpkgs/zen-browser/template"

echo "### Checking for zen-browser updates..."

LATEST_VERSION=$(gh api repos/$REPO/releases/latest --jq .tag_name | sed 's/^v//')
CURRENT_VERSION=$(grep '^version=' "$TPL" | cut -d= -f2)

printf "Latest version is: %s\nLatest built version is: %s\n" "${LATEST_VERSION}" "${CURRENT_VERSION}"
[ "${CURRENT_VERSION}" = "${LATEST_VERSION}" ] && printf "No new version to release\n" && exit 0

if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
    echo "No update required. Current version: $CURRENT_VERSION"
    exit 0
fi

echo "Update found: $CURRENT_VERSION -> $LATEST_VERSION"

URL_X86="https://github.com/$REPO/releases/download/${LATEST_VERSION}/zen.linux-x86_64.tar.xz"
URL_AARCH64="https://github.com/$REPO/releases/download/${LATEST_VERSION}/zen.linux-aarch64.tar.xz"

echo "Calculating checksums..."
CHK_X86=$(curl -L -s "$URL_X86" | sha256sum | awk '{print $1}')
CHK_AARCH64=$(curl -L -s "$URL_AARCH64" | sha256sum | awk '{print $1}')

if [ -z "$CHK_X86" ] || [ -z "$CHK_AARCH64" ]; then
    echo "Error: Failed to fetch checksums."
    exit 1
fi

echo "Checksums: x86_64=$CHK_X86 aarch64=$CHK_AARCH64"

sed -i "s/^version=.*/version=$LATEST_VERSION/" "$TPL"
sed -i "s/^revision=.*/revision=1/" "$TPL"

# Template structure: if (aarch64) { checksum } else { checksum }
# First checksum line = aarch64, second = x86_64
awk -v chk_aarch="$CHK_AARCH64" -v chk_x86="$CHK_X86" '
  /^checksum=/ && n_checksums == 0 { $0="checksum=\"" chk_aarch "\""; n_checksums++ }
  /^checksum=/ && n_checksums == 1 { $0="checksum=\"" chk_x86 "\""; n_checksums++ }
  { print }
' "$TPL" > "${TPL}.tmp" && mv "${TPL}.tmp" "$TPL"

echo "NEW_VERSION=$LATEST_VERSION" >> $GITHUB_ENV
echo "### Done! zen-browser updated to $LATEST_VERSION"
