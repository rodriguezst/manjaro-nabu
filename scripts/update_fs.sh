#!/bin/bash

./scripts/image_mount.sh $1 rootfs
chroot rootfs pacman -R linux61
rsync -a overlay/ rootfs/
# update-initramfs
# update-grub
umount -R rootfs
rm -rf rootfs
