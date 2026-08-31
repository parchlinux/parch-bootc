# Parch Linux Bootc (Immutable OS)

An image-mode, immutable workstation operating system based on Parch Linux, delivered as an OCI bootable container powered by [bootc](https://github.com/bootc-dev/bootc), [OSTree](https://ostreedev.github.io/ostree/), and [ComposeFS](https://github.com/containers/composefs).

## Features

- **Declarative & Cloud-Native**: Defined entirely in `Containerfile` and built in standard container CI pipelines.
- **Atomic Updates & Rollbacks**: Updates deploy atomically via OCI layer transport. Easily revert bad updates with `bootc rollback`.
- **Three-Zone Filesystem Isolation**:
  - `/usr` — Strictly read-only immutable system binaries and libraries.
  - `/etc` — Managed configuration tree with automated three-way merge on upgrades.
  - `/var` — Persistent, stateful user and application data (`/home` -> `/var/home`).
- **No Local Pacman Drift**: The operating system is fully immutable; pacman is purged from runtime to prevent configuration drift.
- **Desktop Environment**: Minimal KDE Plasma Desktop with Wayland, Dolphin (file manager), Kate (text editor), Ark (archive manager), Discover (software center), Firefox, and official Parch branding.
- **Application Delivery & Compatibility Ecosystem**:
  - **Flatpak & Flathub**: Decoupled native Linux desktop applications.
  - **Distrobox & Kontainer**: Run any Linux distribution (Ubuntu, Fedora, Arch, Debian) inside terminal or GUI and export applications effortlessly.
  - **Waydroid & Parchdroid**: Full Android runtime container with Parchdroid GUI for running Android APKs and mobile applications.
- **Kernel**: `linux-lts` for long-term hardware stability and reliability.

---

## Directory Structure

```
├── .github/workflows/build.yaml  # Release-driven CI/CD container build workflow
├── Containerfile                 # Multi-layer declarative OS definition
├── Justfile                      # Automation recipes (build, lint, disk, VM)
├── README.md                     # Documentation
└── rootfs/                       # System assets copied into container root
    ├── etc/
    │   ├── pacman.d/             # Mirrorlist configuration (Parch & Chaotic-AUR)
    │   └── sudoers.d/            # Wheel group sudo configuration
    └── usr/
        ├── lib/
        │   ├── dracut/           # Dracut ostree & bootc initramfs configuration
        │   ├── ostree/           # ComposeFS & sysroot readonly configurations
        │   ├── sddm/             # SDDM display manager defaults
        │   ├── systemd/system/   # Flathub initialization & bootc auto-update units
        │   └── tmpfiles.d/       # /var directory structure provisioning
        └── share/plasma/         # Custom KDE default panel layout with Parch icon
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

Or run the interactive Python installer:

```bash
sudo python3 ../apadana-installer/installer.py
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
