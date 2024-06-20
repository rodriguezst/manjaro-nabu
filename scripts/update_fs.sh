#!/bin/bash

IMG_FILE="$1"
if [[ "$IMG_FILE" == *.xz ]]; then
  unxz $IMG_FILE
  IMG_FILE="${IMG_FILE%.xz}"
fi
./scripts/image_mount.sh $IMG_FILE rootfs
chroot rootfs pacman -R linux61
rsync -a overlay/ rootfs/
# update-initramfs
# update-grub
umount -R rootfs
rm -rf rootfs
