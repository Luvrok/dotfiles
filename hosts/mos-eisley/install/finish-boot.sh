#!/bin/bash
# one-shot boot into the new system, fallback to the old root on vda3
set -e
G=$(ls /nix/store/*-grub-*/bin/grub-editenv | head -1)

# panic=30 новому ядру
sed -i '/^  linux (\$drive1)\/\/kernels\// s/lsm=landlock,yama,bpf$/lsm=landlock,yama,bpf panic=30/' \
  /mnt/boot/grub/grub.cfg

# запись для старого корня
cat >> /mnt/boot/grub/grub.cfg <<'EOF'

menuentry "old nixos (vda3)" {
  insmod part_gpt
  insmod ext2
  set root=(hd0,gpt3)
  configfile /boot/grub/grub.cfg
}
EOF

# default = индекс старой записи; проверь grep '^menuentry' перед запуском!
sed -i 's/^      set default=0$/      set default=2/' /mnt/boot/grub/grub.cfg
"$G" /mnt/boot/grub/grubenv set next_entry=0

grep -nE '^(menuentry|submenu) |set default=' /mnt/boot/grub/grub.cfg
"$G" /mnt/boot/grub/grubenv list

umount /mnt/boot
umount /mnt
sync
