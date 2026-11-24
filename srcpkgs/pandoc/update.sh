#!/bin/bash

set -euo pipefail

TPL="srcpkgs/pandoc/template"
UPSTREAM="https://raw.githubusercontent.com/void-linux/void-packages/master/srcpkgs/pandoc/template"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

download() {
    curl --fail --location --silent --show-error --retry 3 --output "$2" "$1"
}

download "$UPSTREAM" "$tmp/upstream"
version=$(sed -n 's/^version=//p' "$tmp/upstream")
revision=$(sed -n 's/^revision=//p' "$tmp/upstream")
if ! [[ $version =~ ^[0-9]+(\.[0-9]+)*$ && $revision =~ ^[1-9][0-9]*$ ]]; then
    echo "Error: could not read Pandoc's version and revision from Void." >&2
    exit 1
fi

current_version=$(sed -n 's/^version=//p' "$TPL")
current_revision=$(sed -n 's/^revision=//p' "$TPL")
if [ "$version" = "$current_version" ] && [ "$revision" = "$current_revision" ]; then
    echo "Pandoc is already at ${version}_${revision}."
    exit 0
fi

if [ "$version" != "$current_version" ]; then
    download "https://github.com/jgm/pandoc/releases/download/${version}/pandoc-${version}-linux-arm64.tar.gz" "$tmp/archive"
    download "https://raw.githubusercontent.com/jgm/pandoc/${version}/COPYRIGHT" "$tmp/COPYRIGHT"
    archive_sha=$(sha256sum < "$tmp/archive")
    license_sha=$(sha256sum < "$tmp/COPYRIGHT")
    sed -e "s/^version=.*/version=$version/" \
        -e "s/^revision=.*/revision=$revision/" \
        -e "/^checksum=/,+1c\\checksum=\"${archive_sha%% *}\n ${license_sha%% *}\"" \
        "$TPL" > "$tmp/template"
else
    sed "s/^revision=.*/revision=$revision/" "$TPL" > "$tmp/template"
fi

mv "$tmp/template" "$TPL"
if [ -n "${GITHUB_ENV:-}" ]; then
    printf 'NEW_VERSION=%s_%s\n' "$version" "$revision" >> "$GITHUB_ENV"
fi
echo "Updated Pandoc to ${version}_${revision}."
