# docktordreh/void-packages

Unofficial package repository for **Void Linux**. It adds packages that are unavailable or difficult to build on **aarch64**.

Current packages:

* `bitwarden-desktop` for `aarch64` and `x86_64`
* `openscad-dev` for `aarch64` and `x86_64`
* `zen-browser` for `aarch64` and `x86_64`
* `linux-virt`, a kernel for virtual machine guests on `aarch64` and `x86_64`

[![Void Linux](https://img.shields.io/badge/Void_Linux-packages-478061?logo=linux)](https://voidlinux.org/)
[![Build](https://img.shields.io/github/actions/workflow/status/docktordreh/void-packages/build.yml?label=build\&logo=githubactions)](https://github.com/docktordreh/void-packages/actions)
[![Release](https://img.shields.io/github/v/release/docktordreh/void-packages?logo=github)](https://github.com/docktordreh/void-packages/releases)

## Repository

Add the repository:

```sh
printf '%s\n' \
  'repository=https://github.com/docktordreh/void-packages/releases/latest/download/' \
  | sudo tee /etc/xbps.d/docktordreh.conf
```

Then synchronize XBPS:

```sh
sudo xbps-install -S
```

On first use, verify and accept the repository signing key fingerprint.

## Packages

| Package              | Architectures       | Description                                  |
| -------------------- | ------------------- | -------------------------------------------- |
| `bitwarden-desktop`  | `aarch64`, `x86_64` | Bitwarden password manager desktop client   |
| `openscad-dev`       | `aarch64`, `x86_64` | Solid 3D CAD modeller                       |
| `zen-browser`        | `aarch64`, `x86_64` | Zen Browser binary package                   |
| `linux-virt`         | `aarch64`, `x86_64` | Linux kernel for virtual machine guests      |
| `linux-virt-headers` | `aarch64`, `x86_64` | Matching kernel headers                      |

### Zen Browser

Install with:

```sh
sudo xbps-install zen-browser
```

The package uses the upstream Zen Browser binary for each architecture.

### linux-virt

`linux-virt` is a Void kernel flavor for virtual machine guests.

It includes general-purpose guest and VirtIO support while omitting hardware support that virtual machines do not need.

The package tracks Void's current kernel series and patch release. Its
checked-in architecture configs are generated from Void's matching baseline
with the fragments in the active `srcpkgs/linux-virt<series>/files/config/`
directory. When Void moves to a new series, the updater creates a new
`linux-virt<series>` package, updates both kernel and headers meta dependencies,
and retains the five newest series for co-installable upgrades.

Regenerate and validate the active series with:

```sh
REGENERATE_CONFIGS=1 bash srcpkgs/linux-virt6.18/update.sh
```

## Automation

GitHub Actions handles package builds, signing, releases, and automatic updates where supported.

## Disclaimer

This is an unofficial repository and is not affiliated with the Void Linux project.
