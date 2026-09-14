#!/bin/bash

set -euo pipefail

REPO="bitwarden/clients"
TPL="srcpkgs/bitwarden-desktop/template"

echo "### Checking for bitwarden-desktop updates..."

LATEST_TAG=$(
    gh api "repos/${REPO}/releases?per_page=100" --paginate \
        --jq '.[] | select(.tag_name | startswith("desktop-v")) | select(.draft == false and .prerelease == false) | .tag_name' |
        awk 'NR == 1 { print }'
)
if [ -z "$LATEST_TAG" ]; then
    echo "Error: No stable desktop release found."
    exit 1
fi

LATEST_VERSION=${LATEST_TAG#desktop-v}
CURRENT_VERSION=$(sed -n 's/^version=//p' "$TPL")

printf "Latest version is: %s\nLatest built version is: %s\n" \
    "$LATEST_VERSION" "$CURRENT_VERSION"
if [ "$CURRENT_VERSION" = "$LATEST_VERSION" ]; then
    echo "No update required."
    exit 0
fi

asset_url() {
    gh api "repos/${REPO}/releases/tags/${LATEST_TAG}" \
        --jq ".assets[] | select(.name == \"$1\") | .browser_download_url"
}

URL_AARCH64=$(asset_url "bitwarden_${LATEST_VERSION}_arm64.tar.gz")
URL_X86=$(asset_url "bitwarden_${LATEST_VERSION}_x64.tar.gz")
if [ -z "$URL_AARCH64" ] || [ -z "$URL_X86" ]; then
    echo "Error: Release is missing a Linux archive."
    exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

checksum() {
    curl --fail --location --silent --show-error --retry 3 \
        --output "$TMPDIR/archive" "$1"
    sha256sum "$TMPDIR/archive" | cut -d' ' -f1
}

CHK_AARCH64=$(checksum "$URL_AARCH64")
CHK_X86=$(checksum "$URL_X86")

sed -i "s/^version=.*/version=$LATEST_VERSION/; s/^revision=.*/revision=1/" "$TPL"
awk -v chk_aarch64="$CHK_AARCH64" -v chk_x86="$CHK_X86" '
    /^[[:space:]]*checksum=/ {
        checksums++
        match($0, /^[[:space:]]*/)
        indent=substr($0, RSTART, RLENGTH)
        if (checksums == 1) {
            print indent "checksum=\"" chk_aarch64 "\""
            next
        }
        if (checksums == 2) {
            print indent "checksum=\"" chk_x86 "\""
            next
        }
    }
    { print }
' "$TPL" > "${TPL}.tmp"
mv "${TPL}.tmp" "$TPL"

if [ -n "${GITHUB_ENV:-}" ]; then
    printf 'NEW_VERSION=%s\n' "$LATEST_VERSION" >> "$GITHUB_ENV"
fi
echo "### Done! bitwarden-desktop updated to $LATEST_VERSION"
