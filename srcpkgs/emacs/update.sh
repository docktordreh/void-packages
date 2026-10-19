#!/bin/bash

set -euo pipefail

# Mirror Void's upstream Emacs template and restrict this repository's build
# to the aarch64 target.
UPSTREAM="https://raw.githubusercontent.com/void-linux/void-packages/master/srcpkgs/emacs/template"
TPL="srcpkgs/emacs/template"

echo "Checking for Emacs updates..."

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

curl --fail --location --silent --show-error --retry 3 \
	--output "$TMPDIR/upstream" "$UPSTREAM"

if grep -q '^archs=' "$TMPDIR/upstream"; then
	sed 's/^archs=.*/archs="aarch64"/' "$TMPDIR/upstream" > "$TMPDIR/template"
else
	sed '/^revision=/a archs="aarch64"' "$TMPDIR/upstream" > "$TMPDIR/template"
fi

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
echo "Updated Emacs to $LATEST_VERSION"
