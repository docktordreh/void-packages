#!/bin/bash
# Update linux-virt6.18 package to match upstream
set -euo pipefail

TPL="srcpkgs/linux-virt6.18/template"
REPO="void-linux/void-packages"

# Fetch upstream version
LATEST=$(curl -sL "https://raw.githubusercontent.com/$REPO/master/srcpkgs/linux6.18/template" | grep '^version=' | cut -d= -f2)
CURRENT=$(grep '^version=' "$TPL" | cut -d= -f2)

echo "Current: $CURRENT"
echo "Upstream: $LATEST"

if [ "$LATEST" = "$CURRENT" ]; then
    echo "Already up-to-date"
    exit 0
fi

# Update version and reset revision
sed -i "s/^version=.*/version=$LATEST/" "$TPL"
sed -i "s/^revision=.*/revision=1/" "$TPL"

echo "Updated to $LATEST"
echo "NEW_VERSION=$LATEST" >> "$GITHUB_ENV"
