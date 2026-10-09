#!/bin/bash

set -euo pipefail

# Void template plus the fix from Supreeeme/xwayland-satellite#495: on niri
# (and other Smithay compositors) the X screen lagged one output mode change
# behind, so X11 apps kept the old size after a resize. Mirror the upstream
# template (version, checksum, build steps) and bump its revision by one so
# this package wins over Void's build of the same version. Remove this
# package once the fix is in a release Void ships.
UPSTREAM="https://raw.githubusercontent.com/void-linux/void-packages/master/srcpkgs/xwayland-satellite/template"
TPL="srcpkgs/xwayland-satellite/template"

echo "Checking for xwayland-satellite updates..."

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

curl --fail --location --silent --show-error --retry 3 \
    --output "$TMPDIR/upstream" "$UPSTREAM"

revision=$(sed -n 's/^revision=//p' "$TMPDIR/upstream")
if [ -z "$revision" ]; then
    echo "Error: Upstream template has no revision line."
    exit 1
fi
sed "s/^revision=.*/revision=$((revision + 1))/" "$TMPDIR/upstream" > "$TMPDIR/template"

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
echo "Updated xwayland-satellite to $LATEST_VERSION"
