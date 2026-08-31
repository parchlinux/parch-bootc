# Parch Linux Bootc (Immutable OS)

An image-mode, immutable workstation operating system based on Parch Linux, delivered as an OCI bootable container powered by [bootc](https://github.com/bootc-dev/bootc), [OSTree](https://ostreedev.github.io/ostree/), and [ComposeFS](https://github.com/containers/composefs).

## Features

- **Declarative & Cloud-Native**: Defined entirely in `Containerfile` and built in standard container CI pipelines.
- **Atomic Updates & Rollbacks**: Updates deploy atomically via OCI layer transport. Easily revert bad updates with `bootc rollback`.
- **Three-Zone Filesystem Isolation**:
  - `/usr` — Strictly read-only immutable system binaries and libraries.
  - `/etc` — Managed configuration tree with automated three-way merge on upgrades.
  - `/var` — Persistent, stateful user and application data (`/home` -> `/var/home`).
- **No Local Pacman Drift**: The operating system is fully immutable; pacman package management is decoupled from runtime host state.
- **Desktop Environment**: Minimal KDE Plasma Desktop with Wayland, Dolphin (file manager), Kate (text editor), Ark (archive manager), Discover (software center), and Firefox.
- **Application Delivery**: Decoupled user and desktop applications powered by Flatpak and Flathub.
- **Kernel**: `linux-lts` for long-term hardware stability and reliability.

---

## Directory Structure

```
├── .github/workflows/build.yaml  # CI/CD container build & signing workflow
├── Containerfile                 # Multi-layer declarative OS definition
├── Justfile                      # Automation recipes (build, lint, disk, VM)
├── README.md                     # Documentation
└── rootfs/                       # System assets copied into container root
    ├── etc/pacman.d/             # Mirrorlist configuration
    └── usr/lib/
        ├── dracut/dracut.conf.d/ # Dracut ostree & bootc initramfs configuration
        ├── ostree/               # ComposeFS & sysroot readonly configurations
        ├── sddm/sddm.conf.d/     # SDDM display manager defaults
        ├── systemd/system/       # Flathub initialization & bootc auto-update units
        └── tmpfiles.d/           # /var directory structure provisioning
```

---

## Developer Workflow

### 1. Build the Container Image

```bash
just build
```

### 2. Lint Container Image

```bash
just lint
```

### 3. Generate Bootable Virtual Disk (QCOW2 / RAW / ISO)

Generate a bootable virtual disk media using `bootc-image-builder`:

```bash
just build-disk qcow2
```

### 4. Test in QEMU / KVM

Launch the generated QCOW2 image in a local virtual machine:

```bash
just run-vm
```

---

## Installation & Maintenance

### Bare-Metal Direct Installation

Boot from any live Linux environment with Podman:

```bash
sudo podman run \
    --privileged \
    --pid=host \
    --net=host \
    --security-opt label=type:unconfined_t \
    -v /dev:/dev \
    ghcr.io/parchlinux/parch-bootc:latest \
    bootc install to-disk /dev/nvme0n1
```

### Updating & Staging

Check and stage OS updates in the background:

```bash
sudo bootc upgrade
```

To roll back to the prior deployment:

```bash
sudo bootc rollback
```

---

## License

GPL-3.0 License.
