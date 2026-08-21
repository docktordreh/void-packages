#!/usr/bin/env bash
# Generate complete configs from the matching Void kernel configs.
set -euo pipefail

files_dir=$(CDPATH=; cd -- "$(dirname -- "$0")" && pwd)
package_dir=$(CDPATH=; cd -- "$files_dir/.." && pwd)
package_name=$(sed -n 's/^pkgname=//p' "$package_dir/template" | head -n1)
void_packages=
kernel_source=
output_dir=$files_dir
revision=1

usage() {
	cat <<'EOF'
Usage: generate-dotconfigs.sh --void-packages DIR --kernel-source DIR [options]

  --void-packages DIR  Void checkout containing srcpkgs/linux and linux<series>
  --kernel-source DIR  unpacked and patched matching Linux source tree
  --output DIR         output directory (default: this package's files dir)
  --revision N         package revision for CONFIG_LOCALVERSION (default: 1)
EOF
}

while [ "$#" -gt 0 ]; do
	case "$1" in
		--void-packages) void_packages=$2; shift 2;;
		--kernel-source) kernel_source=$2; shift 2;;
		--output) output_dir=$2; shift 2;;
		--revision) revision=$2; shift 2;;
		-h|--help) usage; exit 0;;
		*) usage >&2; exit 2;;
	esac
done

[ -n "$void_packages" ] || { usage >&2; exit 2; }
[ -n "$kernel_source" ] || { usage >&2; exit 2; }
[ -x "$kernel_source/scripts/config" ] || {
	echo "missing Linux scripts/config: $kernel_source" >&2
	exit 1
}
[ -x "$kernel_source/scripts/kconfig/merge_config.sh" ] || {
	echo "missing Linux merge_config.sh: $kernel_source" >&2
	exit 1
}

series=$(sed -n 's/^version=//p' "$void_packages/srcpkgs/linux/template" | head -n1)
base_dir=$void_packages/srcpkgs/linux${series}
[ -d "$base_dir/files" ] || {
	echo "missing Void kernel package: $base_dir" >&2
	exit 1
}

mkdir -p "$output_dir"
tmpdir=$(mktemp -d "${TMPDIR:-/tmp}/linux-virt-config.XXXXXX")
trap 'rm -rf "$tmpdir"' EXIT

fragment_common=$files_dir/config/common-virt.fragment
fragment_usb=$files_dir/config/usb-passthrough.fragment
fragment_arm=$files_dir/config/arm64-physical.fragment

# Values here are the non-negotiable guest path. The fragment policy chooses
# modules; these calls re-assert the path after every dependency resolution.
force_y=(
	VIRTUALIZATION HYPERVISOR_GUEST PARAVIRT KVM_GUEST BLOCK NET INET IPV6
	PCI USB DRM EFI EFI_STUB
)
force_m=(
	VIRTIO_PCI VIRTIO_MMIO VIRTIO_BLK VIRTIO_NET SCSI_VIRTIO VIRTIO_CONSOLE
	HW_RANDOM_VIRTIO VIRTIO_BALLOON VIRTIO_MEM VIRTIO_INPUT VIRTIO_FS
	VSOCKETS VIRTIO_VSOCKETS BRIDGE VETH TUN WIREGUARD OVERLAY_FS FUSE_FS
	DRM_VIRTIO_GPU DRM_QXL DRM_VMWGFX USB_XHCI_HCD USB_EHCI_HCD USB_OHCI_HCD
	USB_UHCI_HCD USB_STORAGE USB_HID HID_GENERIC SND_USB_AUDIO USB_SERIAL
	BT BT_HCIBTUSB
)

for arch in x86_64 arm64; do
	case "$arch" in
		x86_64) kernel_arch=x86_64; baseline_arch=x86_64;;
		arm64) kernel_arch=arm64; baseline_arch=arm64;;
	esac
	baseline=$base_dir/files/${baseline_arch}-dotconfig
	[ -f "$baseline" ] || {
		echo "missing Void baseline: $baseline" >&2
		exit 1
	}

	work=$tmpdir/$arch
	mkdir -p "$work"
	fragments=("$fragment_common" "$fragment_usb")
	[ "$arch" = arm64 ] && fragments+=("$fragment_arm")
	fragments+=("$files_dir/config/${arch}-virt.fragment")

	(
		cd "$work"
		KCONFIG_CONFIG="$work/.config" \
			"$kernel_source/scripts/kconfig/merge_config.sh" -m -y \
			"$baseline" "${fragments[@]}"
		"$kernel_source/scripts/config" --file .config \
			--set-str LOCALVERSION "_${revision}-virt"
		for symbol in "${force_y[@]}"; do
			"$kernel_source/scripts/config" --file .config --enable "$symbol"
		done
		for symbol in "${force_m[@]}"; do
			"$kernel_source/scripts/config" --file .config --module "$symbol"
		done
		make -C "$kernel_source" O="$work" ARCH="$kernel_arch" olddefconfig
		# Kconfig selects HWMON from retained stale driver entries; no VM path needs it.
		for symbol in HWMON HWMON_VID; do
			"$kernel_source/scripts/config" --file .config --disable "$symbol"
		done
	)

	cp "$work/.config" "$output_dir/${arch}-dotconfig"

	# Compare normalized symbol values, not comments or ordering.
	awk '
		/^CONFIG_[A-Za-z0-9_]+=/{split($0, a, "="); print a[1] "=" a[2]}
		/^# CONFIG_[A-Za-z0-9_]+ is not set/{print $2 "=n"}
	' "$baseline" | sort > "$work/base.normalized"
	awk '
		/^CONFIG_[A-Za-z0-9_]+=/{split($0, a, "="); print a[1] "=" a[2]}
		/^# CONFIG_[A-Za-z0-9_]+ is not set/{print $2 "=n"}
	' "$work/.config" | sort > "$work/new.normalized"
	awk -F= '
		NR == FNR { old[$1] = $2; next }
		{ new[$1] = $2 }
		END {
			for (key in old) if (key in new && old[key] != new[key]) {
				if (old[key] == "m" && new[key] == "y") my++
				else if (old[key] == "y" && new[key] == "m") ym++
				else if (new[key] == "n") disabled++
				else if (old[key] == "n") enabled++
			}
			printf "  disabled: %d\n  enabled: %d\n  module -> builtin: %d\n  builtin -> module: %d\n", disabled + 0, enabled + 0, my + 0, ym + 0
		}
	' "$work/base.normalized" "$work/new.normalized" > "$tmpdir/drift-$arch"
	done

{
	echo "$package_name config drift against Void $series"
	for arch in x86_64 arm64; do
		echo "$arch:"
		cat "$tmpdir/drift-$arch"
	done
} | tee "$output_dir/config-drift.txt"

"$files_dir/validate-dotconfigs.sh" --config-dir "$output_dir"
