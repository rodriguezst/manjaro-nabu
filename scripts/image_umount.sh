#!/bin/bash

# Check if a mount directory is provided as argument
if [ $# -ne 1 ]; then
  echo "Usage: $0 <mount_directory>"
  exit 1
fi

BASE_DIR=$1

CHROOT_DIRS=(
    "$BASE_DIR/proc"
    "$BASE_DIR/sys"
    "$BASE_DIR/dev/pts"
    "$BASE_DIR/dev"
    "$BASE_DIR"
)

for dir in "${CHROOT_DIRS[@]}"
do
  echo "Killing processes using $dir..."
  lsof $dir
  for pid in $(lsof -t "$dir"); do 
    kill $pid
    # Wait for process to terminate
    sleep 5
    if kill -0 $pid 2>/dev/null; then
      # Force process to terminate
      echo "Forcing pid $pid to terminate..."
      kill -9 $pid
    fi
  done
done

echo "Unmounting directories..."

for dir in "${CHROOT_DIRS[@]}"
do
  umount -R "$dir"
  if [ $? -ne 0 ]; then
    echo "Error unmounting $dir"
  fi
done