FROM docker.io/archlinux/archlinux:latest AS builder

# Prevent interactive prompts
ENV KEYRING_IMPORT=noninteractive

# Copy configuration assets
COPY rootfs/ /

# Configure Arch, Parch, and Chaotic-AUR repositories & keys
RUN pacman-key --init && \
    pacman-key --populate archlinux && \
    pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com && \
    pacman-key --lsign-key 3056513887B78AEB && \
    printf "\nNoExtract = usr/share/help/* usr/share/doc/* usr/share/man/* usr/share/info/* usr/share/gtk-doc/*\n" >> /etc/pacman.conf

# Inject Parch [world], Chaotic-AUR, and Void repositories at the top of pacman.conf (before [core])
RUN sed -i '/^\[core\]/i [world]\nSigLevel = Optional TrustAll\nInclude = /etc/pacman.d/parch-mirrors\n\n[chaotic-aur]\nSigLevel = Optional TrustAll\nInclude = /etc/pacman.d/chaotic-mirrorlist\n\n[void]\nSigLevel = Optional TrustAll\nServer = https://mirror.parchlinux.ir/\$repo/\$arch\n\n' /etc/pacman.conf

# Update keyrings and base packages, pre-installing Parch font/emoji stack first to prevent noto-fonts-emoji conflict
RUN --mount=type=tmpfs,dst=/tmp \
    pacman -Sy --noconfirm archlinux-keyring && \
    pacman -Syu --noconfirm glibc && \
    pacman -S --noconfirm parchlinux-keyring chaotic-keyring chaotic-mirrorlist parch-branding parch-wallpaper-damavand ttf-apple-emoji parch-emoji-ios || true

# Install Base System, Linux LTS Kernel, Bootc, Composefs, Filesystem Utilities, and Container Stack
RUN --mount=type=tmpfs,dst=/tmp \
    pacman -S --noconfirm \
    base \
    linux-lts \
    linux-firmware \
    dracut \
    ostree \
    composefs \
    bootc \
    skopeo \
    podman \
    flatpak \
    distrobox \
    btrfs-progs \
    e2fsprogs \
    xfsprogs \
    dosfstools \
    sudo \
    which \
    curl \
    shadow \
    dbus \
    dbus-glib \
    glib2 \
    polkit \
    networkmanager \
    pipewire \
    pipewire-audio \
    pipewire-pulse \
    wireplumber \
    mesa \
    vulkan-intel \
    vulkan-radeon \
    sof-firmware \
    upower \
    bluez \
    bluez-utils

# Install Waydroid Android runtime, LXC stack, and Parchdroid GUI
RUN --mount=type=tmpfs,dst=/tmp \
    pacman -S --noconfirm \
    waydroid \
    lxc \
    dnsmasq \
    iptables-nft \
    parchdroid || true

# Install Minimal KDE Desktop, Dolphin, Kate, Ark, Parchstore, Firefox, and Kontainer
RUN --mount=type=tmpfs,dst=/tmp \
    pacman -S --noconfirm \
    plasma-desktop \
    plasma-workspace \
    kwin \
    plasma-login-manager \
    konsole \
    dolphin \
    kio \
    kio-extras \
    kate \
    ark \
    pastor \
    kontainer \
    plasma-nm \
    plasma-pa \
    powerdevil \
    kscreen \
    bluedevil \
    kinfocenter \
    flatpak-kcm \
    polkit-kde-agent \
    breeze \
    breeze-gtk \
    breeze-icons \
    kde-gtk-config \
    qt6-wayland \
    layer-shell-qt \
    xdg-desktop-portal-kde \
    xdg-user-dirs

# Download and sideload plasma-setup-git
RUN --mount=type=tmpfs,dst=/tmp \
    curl -sL "https://github.com/parchlinux/plasma-setup/releases/download/release-2026.08.31-121018/plasma-setup-git-r560.e772938-1-x86_64.pkg.tar.zst" -o /tmp/plasma-setup.pkg.tar.zst && \
    pacman -U --noconfirm --needed /tmp/plasma-setup.pkg.tar.zst && \
    rm -f /tmp/plasma-setup.pkg.tar.zst && \
    rm -f /etc/xdg/autostart/*plasma-setup*.desktop

# Build and install bootupd
RUN --mount=type=tmpfs,dst=/tmp --mount=type=tmpfs,dst=/root \
    pacman -S --noconfirm make git extra/rust pkgconf openssl && \
    git clone "https://github.com/coreos/bootupd.git" /tmp/bootupd && \
    make -C /tmp/bootupd all install-all && \
    pacman -Rns --noconfirm make git rust pkgconf && \
    pacman -S --clean --noconfirm

# Generate Dracut initramfs with ostree and bootc modules for linux-lts
RUN KERNEL_DIR=$(find /usr/lib/modules -maxdepth 1 -type d | grep '\-lts' | tail -n 1) && \
    KERNEL_VER=$(basename "$KERNEL_DIR") && \
    dracut --kver "$KERNEL_VER" --force "$KERNEL_DIR/initramfs.img"

# Enable Core Systemd Services
RUN systemctl enable plasmalogin.service && \
    systemctl enable NetworkManager.service && \
    systemctl enable bluetooth.service && \
    systemctl enable upower.service && \
    systemctl enable podman.socket && \
    systemctl enable waydroid-container.service && \
    systemctl enable plasma-setup.service && \
    systemctl enable bootloader-update.service && \
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

# Remove pacman and developer/temporary artifacts for an ultra-lean immutable OS
RUN rm -rf /etc/pacman* /var/lib/pacman /var/cache/pacman /usr/lib/sysimage/pacman /usr/share/pacman /usr/bin/pacman* /usr/bin/makepkg* && \
    rm -rf /usr/share/doc/* /usr/share/man/* /usr/share/info/* /usr/share/gtk-doc/* /usr/include/* /root/.cargo /root/.rustup /root/.cache && \
    find /usr/share/locale -mindepth 1 -maxdepth 1 ! -name 'en*' ! -name 'fa*' ! -name 'locale.alias' -exec rm -rf {} + && \
    find /usr/lib /usr/lib64 -name "*.a" -delete 2>/dev/null || true

# Write OS Release metadata
RUN echo 'NAME="Parch Linux"' > /usr/lib/os-release && \
    echo 'PRETTY_NAME="Parch Linux (bootc immutable)"' >> /usr/lib/os-release && \
    echo 'ID=parch' >> /usr/lib/os-release && \
    echo 'ID_LIKE=arch' >> /usr/lib/os-release && \
    echo 'VERSION_ID=rolling' >> /usr/lib/os-release && \
    echo 'HOME_URL="https://parchlinux.com"' >> /usr/lib/os-release && \
    echo 'LOGO=parch-logo' >> /usr/lib/os-release && \
    echo 'VARIANT="KDE Minimal Immutable"' >> /usr/lib/os-release && \
    echo 'VARIANT_ID=kde-minimal' >> /usr/lib/os-release

# Essential Metadata Labels for bootc Compatibility
LABEL containers.bootc=1
ENV container=oci
STOPSIGNAL SIGRTMIN+3
CMD ["/sbin/init"]

# Structural Integrity Validation
RUN bootc container lint
