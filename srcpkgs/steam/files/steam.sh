#!/bin/bash
# Starts Valve's native arm64 Steam client.
#
# Valve's bin_steam.sh only knows the x86 bootstrap. This does the same job
# for linuxarm64: unpack the client into the Steam directory on first run,
# keep the ~/.steam links the client expects, and start it again when it
# exits with 42 after updating itself.
set -euo pipefail

bootstrap=/usr/lib/steam/bootstraplinux_linuxarm64.tar.xz

if [ "$(id -u)" = 0 ]; then
	echo "steam: do not run Steam as root" >&2
	exit 1
fi

# Keep using an existing install that ~/.steam/steam points to.
root=$(readlink -e "$HOME/.steam/steam" 2>/dev/null || true)
if [ -z "$root" ] || [ ! -x "$root/steamrtarm64/steam" ]; then
	root=${XDG_DATA_HOME:-$HOME/.local/share}/Steam
	if [ ! -x "$root/steamrtarm64/steam" ]; then
		(umask 077 && mkdir -p "$root" && tar -xJf "$bootstrap" -C "$root")
	fi
fi

mkdir -p "$HOME/.steam"
ln -sfn "$root" "$HOME/.steam/steam"
ln -sfn "$root" "$HOME/.steam/root"
# arm64 counterpart of the sdk32/sdk64 links, for games that load the Steam
# API from ~/.steam
ln -sfn "$root/linuxarm64" "$HOME/.steam/sdkarm64"

cd "$root"
while :; do
	rc=0
	"$root/steamrtarm64/steam" "$@" || rc=$?
	[ "$rc" = 42 ] || exit "$rc"
done
