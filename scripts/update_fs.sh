#!/bin/bash

IMG_FILE="$1"
if [[ "$IMG_FILE" == *.xz ]]; then
  unxz $IMG_FILE
  IMG_FILE="${IMG_FILE%.xz}"
fi
./scripts/image_mount.sh $IMG_FILE rootfs
if [[ !  $(uname -m | grep -q aarch64) ]]; then
  wget https://github.com/multiarch/qemu-user-static/releases/download/v7.2.0-1/qemu-aarch64-static
  install -m755 qemu-aarch64-static rootfs/

  echo ':aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7:\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff:/qemu-aarch64-static:' | tee /proc/sys/fs/binfmt_misc/register
  #ldconfig.real abi=linux type=dynamic
  echo ':aarch64ld:M::\x7fELF\x02\x01\x01\x03\x00\x00\x00\x00\x00\x00\x00\x00\x03\x00\xb7:\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff:/qemu-aarch64-static:' | tee /proc/sys/fs/binfmt_misc/register
fi
chroot rootfs pacman --noconfirm -R linux61
rsync -a overlay/ rootfs/
# update-initramfs
# update-grub
if [[ !  $(uname -m | grep -q aarch64) ]]; then
  echo -1 | tee /proc/sys/fs/binfmt_misc/aarch64
  echo -1 | tee /proc/sys/fs/binfmt_misc/aarch64ld
  rm rootfs/qemu-aarch64-static
  rm qemu-aarch64-static
fi
umount -R rootfs
rm -rf rootfs
