#!/bin/bash
# Update this kernel series, or create the next series package when Void moves.
set -euo pipefail

package_dir=$(CDPATH=; cd -- "$(dirname -- "$0")" && pwd)
root=$(CDPATH=; cd -- "$package_dir/../.." && pwd)
pkgname=$(sed -n 's/^pkgname=//p' "$package_dir/template" | head -n1)
current_series=${pkgname#linux-virt}
meta_template=$root/srcpkgs/linux-virt/template

VOID_REPO_URL=${VOID_REPO_URL:-https://github.com/void-linux/void-packages.git}
VOID_META_URL=${VOID_META_URL:-https://raw.githubusercontent.com/void-linux/void-packages/master/srcpkgs/linux/template}
KERNEL_SITE=${KERNEL_SITE:-https://cdn.kernel.org/pub/linux}
REGENERATE_CONFIGS=${REGENERATE_CONFIGS:-0}

tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

fetch_template() {
	local series=$1 output=$2
	curl -fsSL "${VOID_TEMPLATE_BASE_URL:-https://raw.githubusercontent.com/void-linux/void-packages/master/srcpkgs/linux${series}/template}" -o "$output"
}

prune_old_series() {
	local dir series
	local -a packages=()
	for dir in "$root"/srcpkgs/linux-virt*; do
		[ -d "$dir" ] || continue
		series=${dir##*linux-virt}
		[[ "$series" =~ ^[0-9]+\.[0-9]+$ ]] || continue
		packages+=("$dir")
	done
	mapfile -t packages < <(printf '%s\n' "${packages[@]}" | sort -V)
	while [ "${#packages[@]}" -gt 5 ]; do
		rm -rf "${packages[0]}"
		packages=("${packages[@]:1}")
	done
}

meta_upstream=$tmpdir/linux-template
curl -fsSL "$VOID_META_URL" -o "$meta_upstream"
target_series=$(sed -n 's/^version=//p' "$meta_upstream" | head -n1)
case "$target_series" in
	*.*.*) target_series=${target_series%.*};;
esac

echo "Current series: $current_series"
echo "Upstream series: $target_series"

if [ "$target_series" != "$current_series" ]; then
	target_dir=$root/srcpkgs/linux-virt${target_series}
	if [ -e "$target_dir" ]; then
		echo "$target_dir already exists; its updater will handle the release"
		exit 0
	fi

	mkdir "$target_dir"
	cp -a "$package_dir/." "$target_dir/"
	sed -i "s/${pkgname}/linux-virt${target_series}/g" "$target_dir/template"

	if ! REGENERATE_CONFIGS=1 bash "$target_dir/update.sh"; then
		rm -rf "$target_dir"
		exit 1
	fi

	sed -i "s/^version=.*/version=$target_series/" "$meta_template"
	prune_old_series
	echo "Created $target_dir and switched linux-virt to $target_series"
	exit 0
fi

upstream_template=$tmpdir/series-template
fetch_template "$current_series" "$upstream_template"
latest=$(sed -n 's/^version=//p' "$upstream_template" | head -n1)
current=$(sed -n 's/^version=//p' "$package_dir/template" | head -n1)

echo "Current release: $current"
echo "Upstream release: $latest"

if [ "$latest" = "$current" ] && [ "$REGENERATE_CONFIGS" != 1 ]; then
	prune_old_series
	echo "Already up-to-date"
	exit 0
fi

# Update release metadata while preserving the local -virt template.
sed -i "s/^version=.*/version=$latest/" "$package_dir/template"
sed -i "s/^revision=.*/revision=1/" "$package_dir/template"
upstream_checksum=$(sed -n '/^checksum="/,/"$/p' "$upstream_template")
awk -v checksum="$upstream_checksum" '
  /^checksum="/ { print checksum; skip=1; next }
  skip && /"$/ { skip=0; next }
  !skip { print }
' "$package_dir/template" > "$tmpdir/template.local"
mv "$tmpdir/template.local" "$package_dir/template"

if [ -n "${GITHUB_ENV:-}" ]; then
	echo "NEW_VERSION=$latest" >> "$GITHUB_ENV"
fi

if [ "$REGENERATE_CONFIGS" != 1 ]; then
	prune_old_series
	exit 0
fi

if [ -n "${VOID_PACKAGES_DIR:-}" ]; then
	void_packages=$VOID_PACKAGES_DIR
else
	git clone --depth=1 "$VOID_REPO_URL" "$tmpdir/void-packages"
	void_packages=$tmpdir/void-packages
fi

if [ -n "${KERNEL_SOURCE:-}" ]; then
	kernel_source=$KERNEL_SOURCE
else
	mkdir -p "$tmpdir/kernel"
	curl -fsSL "$KERNEL_SITE/kernel/v${latest%%.*}.x/linux-${latest%.*}.tar.xz" |
		tar -xJf - -C "$tmpdir/kernel"
	if [ "${latest##*.}" != 0 ]; then
		curl -fsSL "$KERNEL_SITE/kernel/v${latest%%.*}.x/patch-${latest}.xz" |
			xzcat | patch -sNp1 -F0 -d "$tmpdir/kernel/linux-${latest%.*}"
	fi
	kernel_source=$tmpdir/kernel/linux-${latest%.*}
fi

"$package_dir/files/generate-dotconfigs.sh" \
	--void-packages "$void_packages" \
	--kernel-source "$kernel_source"
prune_old_series
