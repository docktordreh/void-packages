#!/bin/bash

set -euo pipefail

# Void ships vagrant in nonfree for x86 only. Mirror the upstream template
# (version, revision, checksum and build steps) and only change what is needed
# to build and publish it here for aarch64.
UPSTREAM="https://raw.githubusercontent.com/void-linux/void-packages/master/srcpkgs/vagrant/template"
TPL="srcpkgs/vagrant/template"

echo "Checking for vagrant updates..."

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

curl --fail --location --silent --show-error --retry 3 \
    --output "$TMPDIR/upstream" "$UPSTREAM"

# The build workflow matches archs literally, so no wildcards. The release
# only publishes the main repository, so drop the nonfree subrepository.
sed -e 's/^archs=.*/archs="aarch64"/' \
    -e '/^repository=nonfree$/d' \
    "$TMPDIR/upstream" > "$TMPDIR/template"

if ! grep -qx 'archs="aarch64"' "$TMPDIR/template"; then
    echo "Error: Upstream template has no archs line to replace."
    exit 1
fi

pkgver() {
    printf '%s_%s\n' "$(sed -n 's/^version=//p' "$1")" \
        "$(sed -n 's/^revision=//p' "$1")"
}

LATEST_VERSION=$(pkgver "$TMPDIR/template")
CURRENT_VERSION=$(pkgver "$TPL" 2>/dev/null || true)

printf "Latest version is: %s\nLatest built version is: %s\n" \
    "$LATEST_VERSION" "$CURRENT_VERSION"
if cmp -s "$TMPDIR/template" "$TPL"; then
    echo "No update required."
    exit 0
fi

mv "$TMPDIR/template" "$TPL"

if [ -n "${GITHUB_ENV:-}" ]; then
    printf 'NEW_VERSION=%s\n' "$LATEST_VERSION" >> "$GITHUB_ENV"
fi
echo "Updated vagrant to $LATEST_VERSION"
