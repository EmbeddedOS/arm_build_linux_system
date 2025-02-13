#!/bin/bash
LINUX_VERSION=6.13.2
BUSYBOX_VERSION=1.36.1

# 1. Download toolchains.
wget https://developer.arm.com/-/media/Files/downloads/gnu/14.2.rel1/binrel/arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz
tar -xvf arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu.tar.xz
mv arm-gnu-toolchain-14.2.rel1-x86_64-aarch64-none-linux-gnu toolchain

# 2. Build kernel.
wget https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${LINUX_VERSION}.tar.xz
tar -xvf linux-${LINUX_VERSION}
mv linux-${LINUX_VERSION} linux
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=../toolchain/bin/aarch64-none-linux-gnu- -C linux defconfig
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=../toolchain/bin/aarch64-none-linux-gnu- -C linux

# 3. Build rootfs.
wget https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2
tar -xvf busybox-${BUSYBOX_VERSION}.tar.bz2
mv busybox-${BUSYBOX_VERSION} busybox
make -j$(nproc) ARCH=arm CROSS_COMPILE=../toolchain/bin/aarch64-none-linux-gnu- -C busybox defconfig
sed -i -e 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/g' busybox/.config
make -j$(nproc) ARCH=arm CROSS_COMPILE=../toolchain/bin/aarch64-none-linux-gnu- -C busybox

mkdir -p rootfs/{bin,sbin,etc,proc,sys,usr/{bin,sbin},dev,lib,var/{log,run}}

sudo mknod -m 660 rootfs/dev/mem c 1 1
sudo mknod -m 660 rootfs/dev/tty2 c 4 2
sudo mknod -m 660 rootfs/dev/tty3 c 4 3
sudo mknod -m 660 rootfs/dev/tty4 c 4 4
sudo mknod -m 660 rootfs/dev/null c 1 3
sudo mknod -m 660 rootfs/dev/zero c 1 5

cp -av busybox/_install/* rootfs/
ln -sf rootfs/bin/busybox rootfs/init

mkdir -p rootfs/etc/init.d/
cat > rootfs/etc/init.d/rcS << EOF
mount -t sysfs none /sys
mount -t proc none /proc
EOF
chmod -R 777 rootfs/etc/init.d/rcS

cd rootfs
find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../rootfs.cpio.gz
cd ../

# 4. Build bootloader.
git clone https://github.com/ARM-software/u-boot.git
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=../toolchain/bin/aarch64-none-linux-gnu- -C u-boot qemu_arm64_defconfig
make -j$(nproc) ARCH=arm64 CROSS_COMPILE=../toolchain/bin/aarch64-none-linux-gnu- -C u-boot

# 5. TODO: Compress to final image.
