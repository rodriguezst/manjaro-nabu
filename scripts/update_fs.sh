#!/bin/bash

ROOTFS_DIR=rootfs

# Check if an .img file and a target directory are provided as arguments
if [ $# -ne 1 ]; then
  echo "Usage: $0 <image_file.img>"
  exit 1
fi

IMG_FILE=$1

# Check if IMG_FILE ends with .xz (compressed file extension)
if [[ "$IMG_FILE" == *.xz ]]; then
  # Decompress the .xz file
  unxz $IMG_FILE
  # Remove the .xz extension from the filename
  IMG_FILE="${IMG_FILE%.xz}"
fi

# Mount the image file to the rootfs directory using the image_mount.sh script
./scripts/image_mount.sh $IMG_FILE $ROOTFS_DIR

# Check if the system architecture is not aarch64 (ARM 64-bit)
if ! uname -m | grep -q aarch64; then
  # Download the QEMU user static binary for aarch64 emulation
  wget --no-verbose https://github.com/multiarch/qemu-user-static/releases/download/v7.2.0-1/qemu-aarch64-static
  # Install the QEMU binary to the rootfs directory with appropriate permissions
  install -m755 qemu-aarch64-static $ROOTFS_DIR/

  # Register the QEMU binary with binfmt_misc to handle aarch64 binaries
  echo ':aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7:\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff:/qemu-aarch64-static:' | tee /proc/sys/fs/binfmt_misc/register > /dev/null

  # Register aarch64 dynamic linker with binfmt_misc
  echo ':aarch64ld:M::\x7fELF\x02\x01\x01\x03\x00\x00\x00\x00\x00\x00\x00\x00\x03\x00\xb7:\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff:/qemu-aarch64-static:' | tee /proc/sys/fs/binfmt_misc/register > /dev/null
fi

# Enter the chroot environment and remove the linux61 package using pacman
chroot $ROOTFS_DIR pacman --noconfirm -R linux61

# Install packages
chroot $ROOTFS_DIR pacman-key --init
chroot $ROOTFS_DIR pacman-key --populate archlinuxarm manjaro manjaro-arm
chroot $ROOTFS_DIR pacman -Syyu rmtfs pd-mapper tqftpserv --noconfirm --noprogressbar
chroot $ROOTFS_DIR systemctl enable qrtr-ns pd-mapper tqftpserv rmtfs

# Add files from the overlay directory to the rootfs directory
rsync -a --chown=root:root overlay/ $ROOTFS_DIR/

# Enable services from overlay
chroot $ROOTFS_DIR systemctl enable qbootctl config-wlan0-mac

# Regenerate initramfs and build UKI image for EFI booting
INSTALLED_KERNEL=$(ls overlay/usr/lib/modules/)
chroot $ROOTFS_DIR mkinitcpio --generate /boot/initramfs-linux.img --kernel $INSTALLED_KERNEL
KERNEL="/boot/vmlinuz-$INSTALLED_KERNEL"
DEVICETREE="/boot/dtb-$INSTALLED_KERNEL"
INITRAMFS="/boot/initramfs-linux.img"
chroot $ROOTFS_DIR pacman -Syyu systemd-ukify --noconfirm --noprogressbar
# UKI needs ARM64 kernel images to be uncompressed
cp $ROOTFS_DIR/$KERNEL Image.gz && gunzip -d Image.gz && mv Image "$ROOTFS_DIR/boot/Image-$INSTALLED_KERNEL"
# Generated UKI image is named grubaa64.efi to match the hardcoded paths in https://github.com/BigfootACA/simple-init/blob/master/src/boot/efi_path.c
mkdir -p "$ROOTFS_DIR/boot/efi/EFI/manjaro"
chroot $ROOTFS_DIR ukify build  \
              --linux="/boot/Image-$INSTALLED_KERNEL" \
              --initrd=$INITRAMFS \
              --cmdline="console=tty0 root=PARTLABEL=linux rw rootwait selinux=0 quiet splash" \
              --devicetree=$DEVICETREE \
              --uname=$INSTALLED_KERNEL \
              --output="/boot/efi/EFI/manjaro/grubaa64.efi"
rm -rf "$ROOTFS_DIR/boot/Image-$INSTALLED_KERNEL"

# If the system architecture is not aarch64, clean up the binfmt_misc registrations and QEMU binary
if ! uname -m | grep -q aarch64; then
  # Unregister the aarch64 binfmt_misc handlers
  echo -1 | tee /proc/sys/fs/binfmt_misc/aarch64 > /dev/null
  echo -1 | tee /proc/sys/fs/binfmt_misc/aarch64ld > /dev/null
  # Remove the QEMU binary from the rootfs and current directories
  rm $ROOTFS_DIR/qemu-aarch64-static
  rm qemu-aarch64-static
fi

# Unmount the rootfs directory and remove it
./scripts/image_umount.sh $ROOTFS_DIR
rm -d $ROOTFS_DIR

# Extract partitions from disk image
./scripts/image_extract.sh $IMG_FILE
