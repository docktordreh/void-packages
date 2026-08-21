#!/usr/bin/env bash
set -euo pipefail

root=$(CDPATH=; cd -- "$(dirname -- "$0")" && pwd)
config_dir=$root

while [ "$#" -gt 0 ]; do
	case "$1" in
		--config-dir) config_dir=$2; shift 2;;
		-h|--help) echo "Usage: validate-dotconfigs.sh [--config-dir DIR]"; exit 0;;
		*) echo "unknown option: $1" >&2; exit 2;;
	esac
done

config_value() {
	local file=$1 symbol=$2
	awk -v symbol="CONFIG_${symbol}" '
		BEGIN { value = "n" }
		$0 == "# " symbol " is not set" { value = "n" }
		index($0, symbol "=") == 1 { value = substr($0, length(symbol) + 2) }
		END { print value }
	' "$file"
}

enabled() {
	case "$(config_value "$1" "$2")" in y|m) return 0;; *) return 1;; esac
}

require_enabled() {
	if ! enabled "$1" "$2"; then
		echo "$1: required CONFIG_$2 is not enabled" >&2
		failed=1
	fi
}

require_disabled() {
	if [ "$(config_value "$1" "$2")" != n ]; then
		echo "$1: unwanted CONFIG_$2 is enabled" >&2
		failed=1
	fi
}

failed=0
for arch in x86_64 arm64; do
	file=$config_dir/${arch}-dotconfig
	[ -s "$file" ] || { echo "missing $file" >&2; failed=1; continue; }
	while IFS=: read -r line content; do
		echo "$file:$line: invalid config syntax: $content" >&2
		failed=1
	done < <(awk '!/^(CONFIG_[A-Za-z0-9_]+=|#|[[:space:]]*$)/ { print NR ":" $0 }' "$file")

	for symbol in \
		VIRTIO VIRTIO_PCI VIRTIO_BLK VIRTIO_NET SCSI_VIRTIO VIRTIO_CONSOLE \
		HW_RANDOM_VIRTIO VIRTIO_BALLOON VIRTIO_INPUT VIRTIO_FS VSOCKETS \
		VIRTIO_VSOCKETS USB USB_XHCI_HCD USB_EHCI_HCD USB_OHCI_HCD USB_UHCI_HCD \
		USB_HID HID_GENERIC USB_STORAGE SND_USB_AUDIO USB_SERIAL BT BT_HCIBTUSB \
		NET INET IPV6 NF_TABLES BRIDGE VETH TUN WIREGUARD OVERLAY_FS FUSE_FS \
		DRM_SIMPLEDRM DRM_VIRTIO_GPU DRM_QXL EXT4_FS XFS_FS BTRFS_FS EFIVAR_FS; do
		require_enabled "$file" "$symbol"
	done

	for symbol in MEDIA_SUPPORT WLAN WWAN NFC WIMAX FIREWIRE THUNDERBOLT IIO HWMON \
		ATA SATA_HOST DRM_AMDGPU DRM_RADEON DRM_NOUVEAU DRM_I915 DRM_XE \
		DRM_ETNAVIV DRM_LIMA DRM_PANFROST DRM_PANTHOR DRM_MSM DRM_ROCKCHIP \
		DRM_TEGRA DRM_VC4 DRM_V3D DRM_SUN4I DRM_MEDIATEK DRM_MESON DRM_SPRD \
		BT_HCIUART BT_HCIBTSDIO BT_MTKSDIO BT_MTKUART BT_INTEL_PCIE; do
		require_disabled "$file" "$symbol"
	done

	if [ "$arch" = arm64 ]; then
		for symbol in ARCH_APPLE ARCH_BCM ARCH_EXYNOS ARCH_MEDIATEK ARCH_QCOM \
			ARCH_ROCKCHIP ARCH_TEGRA ARCH_SUNXI ARCH_MESON ARCH_REALTEK; do
			require_disabled "$file" "$symbol"
		done
	fi
done

if [ "$failed" -ne 0 ]; then
	echo "linux-virt dotconfig validation failed" >&2
	exit 1
fi
echo "linux-virt dotconfig validation passed"
