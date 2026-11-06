#!/bin/bash
# offline shrink of the ubuntu root and creation of a free partition
set -e
fail() { echo "=== FAILED: $*"; exit 1; }

sgdisk -p /dev/vda
sgdisk --backup=/root/vda.gpt /dev/vda || fail "gpt backup"

e2fsck -f -y /dev/vda2
rc=$?; [ "$rc" -le 1 ] || fail "e2fsck rc=$rc"

resize2fs /dev/vda2 10G || fail "resize2fs"

e2fsck -f -y /dev/vda2
rc=$?; [ "$rc" -le 1 ] || fail "e2fsck after rc=$rc"

# vda1: 2048..4095 (1M bios_grub); vda2: 10G = 4096..20975615; vda3: остаток
sgdisk -d 2 -n 2:4096:20975615 -n 3:0:0 -t 3:8300 -c 3:nixos-root /dev/vda || fail "sgdisk"

sgdisk -p /dev/vda
sync
echo "=== DONE"
