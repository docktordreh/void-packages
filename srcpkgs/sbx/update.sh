#!/bin/bash

set -euo pipefail

REPO="docker/sbx-releases"
TPL="srcpkgs/sbx/template"
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

LATEST_TAG=$(gh api "repos/${REPO}/releases/latest" --jq .tag_name)
LATEST_VERSION=${LATEST_TAG#v}
CURRENT_VERSION=$(sed -n 's/^version=//p' "$TPL")

printf "Latest version is: %s\nLatest built version is: %s\n" \
    "$LATEST_VERSION" "$CURRENT_VERSION"
if [ "$LATEST_VERSION" = "$CURRENT_VERSION" ]; then
    echo "No update required."
    exit 0
fi

checksum() {
    local arch=$1
    curl --fail --location --silent --show-error --retry 3 \
        --output "$TMPDIR/${arch}.tar.gz" \
        "https://github.com/${REPO}/releases/download/${LATEST_TAG}/DockerSandboxes-linux-${arch}.tar.gz"
    sha256sum "$TMPDIR/${arch}.tar.gz" | cut -d' ' -f1
}

CHK_X86=$(checksum amd64)
CHK_AARCH64=$(checksum arm64)

sed -i "s/^version=.*/version=$LATEST_VERSION/; s/^revision=.*/revision=1/" "$TPL"
awk -v chk_x86="$CHK_X86" -v chk_aarch64="$CHK_AARCH64" '
    /x86_64\*)/ { arch="x86_64" }
    /aarch64\*)/ { arch="aarch64" }
    /^    checksum=/ {
        if (arch == "x86_64") sub(/checksum=.*/, "checksum=" chk_x86)
        if (arch == "aarch64") sub(/checksum=.*/, "checksum=" chk_aarch64)
    }
    { print }
' "$TPL" > "$TMPDIR/template"
mv "$TMPDIR/template" "$TPL"

if [ -n "${GITHUB_ENV:-}" ]; then
    printf 'NEW_VERSION=%s\n' "$LATEST_VERSION" >> "$GITHUB_ENV"
fi
echo "Updated sbx to $LATEST_VERSION"
