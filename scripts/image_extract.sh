#!/bin/bash

# Check if an .img file and a target directory are provided as arguments
if [ $# -ne 1 ]; then
  echo "Usage: $0 <image_file.img>"
  exit 1
fi

IMG_FILE=$1

# Check if the file exists
if [ ! -f "$IMG_FILE" ]; then
  echo "The file $IMG_FILE does not exist."
  exit 1
fi

# Read the partition list with fdisk
PARTITIONS=$(fdisk -lu "$IMG_FILE" | grep "^$IMG_FILE")
EFI_PARTITION=$(echo "$PARTITIONS" | grep "EFI")
ROOTFS_PARTITION=$(echo "$PARTITIONS" | grep "filesystem")

echo "Partitions found in $IMG_FILE:"
echo "$PARTITIONS"

# Extract rootfs partition
PART_START=$(echo $ROOTFS_PARTITION | awk '{print $2}')
PART_END=$(echo $ROOTFS_PARTITION | awk '{print $3}')
PART_SIZE=$((PART_END - PART_START + 1))
OUTPUT_FILE="${IMG_FILE%.*}-rootfs.img.xz"

echo "Extracting RootFS partition..."
dd if="$IMG_FILE" bs=512 skip=$PART_START count=$PART_SIZE | xz > "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
  echo "RootFS Partition extracted to $OUTPUT_FILE"
else
  echo "Error extracting RootFS partition"
fi

# Mount EFI partition
PART_START=$(echo $EFI_PARTITION | awk '{print $2}')
PART_END=$(echo $EFI_PARTITION | awk '{print $3}')
PART_SIZE=$((PART_END - PART_START + 1))
OUTPUT_FILE="${IMG_FILE%.*}-esp.img.xz"

echo "Extracting EFI partition..."
dd if="$IMG_FILE" bs=512 skip=$PART_START count=$PART_SIZE | xz > "$OUTPUT_FILE"

if [ $? -eq 0 ]; then
  echo "EFI Partition extracted to $OUTPUT_FILE"
else
  echo "Error extracting EFI partition"
fi

echo "Extraction complete."
