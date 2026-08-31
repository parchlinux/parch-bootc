image_name := env("BUILD_IMAGE_NAME", "parch-bootc")
image_tag := env("BUILD_IMAGE_TAG", "latest")
base_dir := env("BUILD_BASE_DIR", ".")
filesystem := env("BUILD_FILESYSTEM", "btrfs")
selinux := env("BUILD_SELINUX", "false")

options := if selinux == "true" { "-v /var/lib/containers:/var/lib/containers:Z -v /etc/containers:/etc/containers:Z -v /sys/fs/selinux:/sys/fs/selinux --security-opt label=type:unconfined_t" } else { "-v /var/lib/containers:/var/lib/containers -v /etc/containers:/etc/containers" }
container_runtime := env("CONTAINER_RUNTIME", `command -v podman >/dev/null 2>&1 && echo podman || echo docker`)

# Build the container image locally
build $image_name=image_name:
    sudo {{container_runtime}} build -f Containerfile -t "${image_name}:latest" .

# Lint the container image using bootc
lint $image_name=image_name:
    sudo {{container_runtime}} run --rm "{{image_name}}:latest" bootc container lint

# Generic bootc runner
bootc *ARGS:
    sudo {{container_runtime}} run \
        --rm --privileged --pid=host \
        -it \
        {{options}} \
        -v /dev:/dev \
        -e RUST_LOG=debug \
        -v "{{base_dir}}:/data" \
        "{{image_name}}:{{image_tag}}" bootc {{ARGS}}

# Generate a virtual disk image (qcow2, raw, iso, ami) using bootc-image-builder
build-disk type="qcow2" output_dir="./output":
    mkdir -p "{{output_dir}}"
    sudo {{container_runtime}} run \
        --rm \
        -it \
        --privileged \
        --pull=newer \
        --security-opt label=type:unconfined_t \
        -v "{{output_dir}}":/output \
        -v /var/lib/containers/storage:/var/lib/containers/storage \
        quay.io/centos-bootc/bootc-image-builder:latest \
        --type {{type}} \
        --target-arch amd64 \
        --filesystem {{filesystem}} \
        "{{image_name}}:{{image_tag}}"

# Test run QCOW2 in QEMU/KVM
run-vm img="./output/qcow2/disk.qcow2" memory="4096" cpus="4":
    qemu-system-x86_64 \
        -enable-kvm \
        -m {{memory}} \
        -smp {{cpus}} \
        -cpu host \
        -drive file={{img}},format=qcow2,if=virtio \
        -bios /usr/share/ovmf/x64/OVMF.fd \
        -vga virtio \
        -display default,show-cursor=on \
        -net nic,model=virtio \
        -net user,hostfwd=tcp::2222-:22

# Loopback install for local verification
generate-bootable-image $base_dir=base_dir $filesystem=filesystem:
    #!/usr/bin/env bash
    if [ ! -e "${base_dir}/bootable.img" ] ; then
        fallocate -l 20G "${base_dir}/bootable.img"
    fi
    just bootc install to-disk --composefs-backend --via-loopback /data/bootable.img --filesystem "${filesystem}" --wipe --bootloader systemd
