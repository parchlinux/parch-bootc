FROM docker.io/archlinux/archlinux:latest AS builder

# Prevent interactive prompts
ENV KEYRING_IMPORT=noninteractive

# Copy configuration assets
COPY rootfs/ /

# Configure Arch and Parch repositories
RUN pacman-key --init && \
    pacman-key --populate archlinux && \
    pacman -Sy --noconfirm archlinux-keyring && \
    sed -i 's/^[[:space:]]*NoExtract/#&/' /etc/pacman.conf

# Inject Parch repository specifications using mirrors from host system
RUN printf "\n[world]\nSigLevel = Optional TrustAll\nInclude = /etc/pacman.d/parch-mirrors\n\n[chaotic-aur]\nSigLevel = Optional TrustAll\nServer = https://cdn-mirror.chaotic.cx/\$repo/\$arch\n" >> /etc/pacman.conf

# Reinstall glibc and upgrade core packages
RUN --mount=type=tmpfs,dst=/tmp \
    pacman -Syu --noconfirm glibc && \
    pacman -S --noconfirm parchlinux-keyring || true

# Install Base System, Linux LTS Kernel, Filesystem Utilities, and Container Stack
RUN --mount=type=tmpfs,dst=/tmp \
    pacman -S --noconfirm \
    base \
    linux-lts \
    linux-lts-headers \
    linux-firmware \
    dracut \
    ostree \
    skopeo \
    podman \
    flatpak \
    btrfs-progs \
    e2fsprogs \
    xfsprogs \
    dosfstools \
    sudo \
    which \
    shadow \
    dbus \
    dbus-glib \
    glib2 \
    polkit \
    networkmanager \
    pipewire \
    pipewire-audio \
    pipewire-pulse \
    wireplumber

# Install Minimal KDE Desktop, File Manager (Dolphin), Kate, Ark, Discover, and Firefox
RUN --mount=type=tmpfs,dst=/tmp \
    pacman -S --noconfirm \
    plasma-desktop \
    plasma-workspace \
    kwin \
    sddm \
    konsole \
    dolphin \
    kio \
    kio-extras \
    kate \
    ark \
    discover \
    packagekit-qt6 \
    firefox \
    plasma-nm \
    powerdevil \
    kscreen \
    breeze \
    breeze-gtk \
    breeze-icons \
    qt6-wayland \
    layer-shell-qt \
    xdg-desktop-portal-kde \
    xdg-user-dirs

# Build and Install bootc
RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root \
    pacman -S --noconfirm make git rust go-md2man && \
    git clone "https://github.com/bootc-dev/bootc.git" /tmp/bootc && \
    make -C /tmp/bootc bin install-all && \
    pacman -Rns --noconfirm make git rust go-md2man

# Generate Dracut initramfs with ostree and bootc modules for linux-lts
RUN KERNEL_DIR=$(find /usr/lib/modules -maxdepth 1 -type d | grep '\-lts' | tail -n 1) && \
    KERNEL_VER=$(basename "$KERNEL_DIR") && \
    dracut --kver "$KERNEL_VER" --force "$KERNEL_DIR/initramfs.img"

# Enable Core Systemd Services
RUN systemctl enable sddm.service && \
    systemctl enable NetworkManager.service && \
    systemctl enable podman.socket && \
    systemctl enable flatpak-add-flathub.service && \
    systemctl enable bootc-autoupdate.timer

# Configure user home defaults and FHS Three-Zone Symlink Layout
RUN sed -i 's|^HOME=.*|HOME=/var/home|' /etc/default/useradd && \
    rm -rf /boot /home /root /usr/local /srv /opt /mnt /var && \
    mkdir -p /sysroot /boot /usr/lib/ostree /var && \
    ln -sT sysroot/ostree /ostree && \
    ln -sT var/roothome /root && \
    ln -sT var/srv /srv && \
    ln -sT var/opt /opt && \
    ln -sT var/mnt /mnt && \
    ln -sT var/home /home && \
    ln -sT ../var/usrlocal /usr/local

# Remove pacman and package management traces for a fully immutable OS
RUN rm -rf /etc/pacman* /var/lib/pacman /var/cache/pacman /usr/lib/sysimage/pacman /usr/share/pacman /usr/bin/pacman* /usr/bin/makepkg*

# Write OS Release metadata
RUN echo 'NAME="Parch Linux"' > /usr/lib/os-release && \
    echo 'PRETTY_NAME="Parch Linux (bootc immutable)"' >> /usr/lib/os-release && \
    echo 'ID=parch' >> /usr/lib/os-release && \
    echo 'ID_LIKE=arch' >> /usr/lib/os-release && \
    echo 'VERSION_ID=rolling' >> /usr/lib/os-release && \
    echo 'HOME_URL="https://parchlinux.com"' >> /usr/lib/os-release && \
    echo 'VARIANT="KDE Minimal Immutable"' >> /usr/lib/os-release && \
    echo 'VARIANT_ID=kde-minimal' >> /usr/lib/os-release

# Essential Metadata Labels for bootc Compatibility
LABEL containers.bootc=1
ENV container=oci
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]

# Structural Integrity Validation
RUN bootc container lint
