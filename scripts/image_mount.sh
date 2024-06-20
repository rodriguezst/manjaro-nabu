#!/bin/bash

# Check if an .img file and a mount directory are provided as arguments
if [ $# -ne 2 ]; then
  echo "Usage: $0 <image_file.img> <mount_directory>"
  exit 1
fi

IMG_FILE=$1
MOUNT_BASE_DIR=$2

# Check if the file exists
if [ ! -f "$IMG_FILE" ]; then
  echo "The file $IMG_FILE does not exist."
  exit 1
fi

# Check if the mount directory exists
if [ ! -d "$MOUNT_BASE_DIR" ]; then
  echo "The directory $MOUNT_BASE_DIR does not exist. Creating directory..."
  mkdir -p "$MOUNT_BASE_DIR"
  if [ $? -ne 0 ]; then
    echo "Failed to create directory $MOUNT_BASE_DIR."
    exit 1
  fi
fi

# Read the partition list with fdisk
PARTITIONS=$(fdisk -lu "$IMG_FILE" | grep "^$IMG_FILE")
EFI_PARTITION=$(echo "$PARTITIONS" | grep "EFI")
ROOTFS_PARTITION=$(echo "$PARTITIONS" | grep "filesystem")

# Partition counter
PART_NUM=0

echo "Partitions found in $IMG_FILE:"
echo "$PARTITIONS"

# Mount rootfs partition
  PART_START=$(echo $ROOTFS_PARTITION | awk '{print $2}')
  PART_END=$(echo $ROOTFS_PARTITION | awk '{print $3}')
  PART_SIZE=$((PART_END - PART_START + 1))
  MOUNT_POINT="$MOUNT_BASE_DIR/"
  mkdir -p "$MOUNT_POINT"

  echo "Mounting RootFS partition on $MOUNT_POINT..."
  mount -o loop,offset=$((512 * PART_START)),sizelimit=$((512 * PART_SIZE)) "$IMG_FILE" "$MOUNT_POINT"
  
  if [ $? -eq 0 ]; then
    echo "RootFS Partition mounted on $MOUNT_POINT"
  else
    echo "Error mounting partition RootFS"
  fi

# Mount EFI partition
  PART_START=$(echo $EFI_PARTITION | awk '{print $2}')
  PART_END=$(echo $EFI_PARTITION | awk '{print $3}')
  PART_SIZE=$((PART_END - PART_START + 1))
  MOUNT_POINT="$MOUNT_BASE_DIR/boot/efi"
  mkdir -p "$MOUNT_POINT"

  echo "Mounting EFI partition on $MOUNT_POINT..."
  mount -o loop,offset=$((512 * PART_START)),sizelimit=$((512 * PART_SIZE)) "$IMG_FILE" "$MOUNT_POINT"
  
  if [ $? -eq 0 ]; then
    echo "EFI Partition mounted on $MOUNT_POINT"
  else
    echo "Error mounting partition EFI"
  fi

# Mount host directories needed for chroot
mount --bind /dev "$MOUNT_BASE_DIR/dev"
mount --bind /dev/pts "$MOUNT_BASE_DIR/dev/pts"
mount --bind /proc "$MOUNT_BASE_DIR/proc"
mount --bind /sys "$MOUNT_BASE_DIR/sys"

echo "Mounting complete. Partitions are mounted in $MOUNT_BASE_DIR."

# Note: To unmount the partitions and remove the mount directory, you can use:
# umount -R $MOUNT_BASE_DIR && rmdir $MOUNT_BASE_DIR
