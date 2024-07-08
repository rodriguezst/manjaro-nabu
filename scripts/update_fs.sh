#!/bin/bash

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
./scripts/image_mount.sh $IMG_FILE rootfs

# Check if the system architecture is not aarch64 (ARM 64-bit)
if ! uname -m | grep -q aarch64; then
  # Download the QEMU user static binary for aarch64 emulation
  wget --no-verbose https://github.com/multiarch/qemu-user-static/releases/download/v7.2.0-1/qemu-aarch64-static
  # Install the QEMU binary to the rootfs directory with appropriate permissions
  install -m755 qemu-aarch64-static rootfs/

  # Register the QEMU binary with binfmt_misc to handle aarch64 binaries
  echo ':aarch64:M::\x7fELF\x02\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x02\x00\xb7:\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff:/qemu-aarch64-static:' | tee /proc/sys/fs/binfmt_misc/register > /dev/null

  # Register aarch64 dynamic linker with binfmt_misc
  echo ':aarch64ld:M::\x7fELF\x02\x01\x01\x03\x00\x00\x00\x00\x00\x00\x00\x00\x03\x00\xb7:\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xff\xfe\xff\xff:/qemu-aarch64-static:' | tee /proc/sys/fs/binfmt_misc/register > /dev/null
fi

# Enter the chroot environment and remove the linux61 package using pacman
chroot rootfs pacman --noconfirm -R linux61

# Install packages
chroot rootfs pacman-key --init
chroot rootfs pacman-key --populate archlinuxarm manjaro manjaro-arm
chroot rootfs pacman -Syyu rmtfs pd-mapper tqftpserv --noconfirm --noprogressbar
chroot rootfs systemctl enable qrtr-ns pd-mapper tqftpserv rmtfs

# Add files from the overlay directory to the rootfs directory
rsync -a overlay/ rootfs/

# Regenerate initramfs and grub configuration
INSTALLED_KERNEL=$(ls overlay/usr/lib/modules/)
chroot rootfs mkinitcpio --generate /boot/initramfs-linux.img --kernel $INSTALLED_KERNEL
#chroot rootfs grub-mkconfig -o /boot/grub/grub.cfg
KERNEL="/boot/vmlinuz-$INSTALLED_KERNEL"
DEVICETREE="/boot/dtb-$INSTALLED_KERNEL"
INITRAMFS="/boot/initramfs-linux.img"
echo '### BEGIN /etc/grub.d/00_header ###
insmod part_gpt
insmod part_msdos
if [ -s $prefix/grubenv ]; then
  load_env
fi
if [ "${next_entry}" ] ; then
   set default="${next_entry}"
   set next_entry=
   save_env next_entry
   set boot_once=true
else
   set default="${saved_entry}"
fi

if [ x"${feature_menuentry_id}" = xy ]; then
  menuentry_id_option="--id"
else
  menuentry_id_option=""
fi

export menuentry_id_option

if [ "${prev_saved_entry}" ]; then
  set saved_entry="${prev_saved_entry}"
  save_env saved_entry
  set prev_saved_entry=
  save_env prev_saved_entry
  set boot_once=true
fi

function savedefault {
  if [ -z "${boot_once}" ]; then
    saved_entry="${chosen}"
    save_env saved_entry
  fi
}

function load_video {
  if [ x$feature_all_video_module = xy ]; then
    insmod all_video
  else
    insmod efi_gop
    insmod efi_uga
    insmod ieee1275_fb
    insmod vbe
    insmod vga
    insmod video_bochs
    insmod video_cirrus
  fi
}

set menu_color_normal=white/black
set menu_color_highlight=green/black

if [ x$feature_default_font_path = xy ] ; then
   font=unicode
else
insmod part_gpt
insmod ext2
search --no-floppy --label --set=root linux
    font="/usr/share/grub/unicode.pf2"
fi

if loadfont $font ; then
  set gfxmode=auto
  load_video
  insmod gfxterm
fi
terminal_input console
terminal_output gfxterm
if [ x$feature_timeout_style = xy ] ; then
  set timeout_style=menu
  set timeout=5
# Fallback normal timeout code in case the timeout_style feature is
# unavailable.
else
  set timeout=5
fi
### END /etc/grub.d/00_header ###' > rootfs/boot/grub/grub.cfg

echo "### BEGIN /etc/grub.d/10_linux ###
menuentry 'Manjaro ARM Setup' --class manjaro --class gnu-linux --class gnu --class os \$menuentry_id_option 'gnulinux-simple-linux' {
        savedefault
        load_video
        set gfxpayload=keep
        insmod gzio
        insmod part_gpt
        insmod ext2
        search --no-floppy --label --set=root linux
        linux   $KERNEL root=PARTLABEL=linux rw quiet splash plymouth.ignore-serial-consoles
        initrd  $INITRAMFS
        devicetree      $DEVICETREE
}" >> rootfs/boot/grub/grub.cfg

# If the system architecture is not aarch64, clean up the binfmt_misc registrations and QEMU binary
if ! uname -m | grep -q aarch64; then
  # Unregister the aarch64 binfmt_misc handlers
  echo -1 | tee /proc/sys/fs/binfmt_misc/aarch64 > /dev/null
  echo -1 | tee /proc/sys/fs/binfmt_misc/aarch64ld > /dev/null
  # Remove the QEMU binary from the rootfs and current directories
  rm rootfs/qemu-aarch64-static
  rm qemu-aarch64-static
fi

# Unmount the rootfs directory and remove it
umount rootfs/dev/pts
umount rootfs/dev
umount rootfs/proc
umount rootfs/sys
umount -R rootfs
rm -d rootfs

# Extract partitions from disk image
./scripts/image_extract.sh $IMG_FILE
