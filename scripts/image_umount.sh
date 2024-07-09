#!/bin/bash

# Check if a mount directory is provided as argument
if [ $# -ne 1 ]; then
  echo "Usage: $0 <mount_directory>"
  exit 1
fi

BASE_DIR=$1

CHROOT_DIRS=('/proc' '/sys' '/dev/pts' '/dev' '/')
 
for dir in "${CHROOT_DIRS[@]}"
do
  echo "Killing processes using $dir..."
  path=$BASE_DIR$dir
  lsof $path
  for pid in $(lsof -t "$path"); do 
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
  path=$BASE_DIR$dir
  umount "$path"
  if [ $? -ne 0 ]; then
    echo "Error unmounting $path"
  fi
done