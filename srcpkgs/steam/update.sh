#!/bin/bash

set -euo pipefail

# Moves the bootstrap client to the build Valve's linuxarm64 manifest
# publishes, and the launcher to the version in Void's (x86) steam template.
MANIFEST="https://client-update.steamstatic.com/steam_client_linuxarm64"
UPSTREAM="https://raw.githubusercontent.com/void-linux/void-packages/master/srcpkgs/steam/template"
TPL="srcpkgs/steam/template"

echo "Checking for steam updates..."

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

curl --fail --location --silent --show-error --retry 3 --output "$TMPDIR/manifest" "$MANIFEST"
curl --fail --location --silent --show-error --retry 3 --output "$TMPDIR/upstream" "$UPSTREAM"

# VDF: "version" "N" at the top, then a block per file
client=$(sed -n 's/^[[:space:]]*"version"[[:space:]]*"\([0-9]*\)".*/\1/p' "$TMPDIR/manifest" | head -n1)
block=$(sed -n '/"bins_linuxarm64_linuxarm64"/,/}/p' "$TMPDIR/manifest")
zip=$(printf '%s\n' "$block" | sed -n 's/^[[:space:]]*"file"[[:space:]]*"\([^"]*\)".*/\1/p')
sha=$(printf '%s\n' "$block" | sed -n 's/^[[:space:]]*"sha2"[[:space:]]*"\([0-9a-f]*\)".*/\1/p')
launcher=$(sed -n 's/^version=//p' "$TMPDIR/upstream")
launcher_sha=$(sed -n 's/^checksum=//p' "$TMPDIR/upstream")

for v in client zip sha launcher launcher_sha; do
    if [ -z "${!v}" ]; then
        echo "Error: could not read $v."
        exit 1
    fi
done

cur_version=$(sed -n 's/^version=//p' "$TPL")
cur_client=$(sed -n 's/^_client=//p' "$TPL")
printf "Latest: launcher %s, client %s\nCurrent: launcher %s, client %s\n" \
    "$launcher" "$client" "$cur_version" "$cur_client"
if [ "$launcher" = "$cur_version" ] && [ "$client" = "$cur_client" ]; then
    echo "No update required."
    exit 0
fi

revision=$(sed -n 's/^revision=//p' "$TPL")
if [ "$launcher" = "$cur_version" ]; then
    revision=$((revision + 1))
else
    revision=1
fi

awk -v ver="$launcher" -v rev="$revision" -v client="$client" -v zip="$zip" \
    -v lsha="$launcher_sha" -v sha="$sha" '
    /^version=/   { print "version=" ver; next }
    /^revision=/  { print "revision=" rev; next }
    /^_client=/   { print "_client=" client; next }
    /^_client_zip=/ { print "_client_zip=" zip; next }
    /^checksum=/  { print "checksum=\"" lsha; getline; print " " sha "\""; next }
    { print }' "$TPL" > "$TMPDIR/template"
mv "$TMPDIR/template" "$TPL"

NEW_VERSION="${launcher}_${revision}"
if [ -n "${GITHUB_ENV:-}" ]; then
    printf 'NEW_VERSION=%s\n' "$NEW_VERSION" >> "$GITHUB_ENV"
fi
echo "Updated steam to $NEW_VERSION (client $client)"
