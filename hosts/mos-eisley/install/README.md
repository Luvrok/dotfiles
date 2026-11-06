# nixos reinstall scripts

Historical scripts from the mos-eisley reinstall (Ubuntu -> NixOS on LVM).

- `build-rescue.sh` — run on Ubuntu. Builds a tiny (~6 MB) ssh-enabled initramfs
  (busybox + dropbear + e2fsprogs + sgdisk) and kexecs it. Fixes the official
  nixos-anywhere kexec image OOM on ~1 GB RAM. Creates `/root/rescue/initrd.gz`.
- `shrink.sh` — run inside that rescue. Shrinks the Ubuntu ext4 on vda2 to 10G
  and creates a free vda3. Backs up the GPT to `/root/vda.gpt` first.
- `finish-boot.sh` — run after `nixos-install` into /mnt. Adds a one-shot GRUB
  boot into the new system (`next_entry=0`) with a fallback to the old root
  (vda3), and `panic=30` so a failed boot returns by itself.

Install steps (short):

1. rescue: `kexec -l /boot/vmlinuz-... --initrd=/root/rescue/initrd.gz --command-line="... panic=30"; kexec -e`
2. rescue: `bash /root/shrink.sh`, then `reboot -f`
3. install NixOS on the free partition, then (for LVM) from the running NixOS:
   - repartition the spare partition into ESP + LVM PV, keep the old root
   - `pvcreate/vgcreate/lvcreate`, `mkfs`, mount /mnt and /mnt/boot
   - `nix copy --to /mnt <system>` + `nixos-install --root /mnt --system <system> --no-root-passwd`
   - `bash finish-boot.sh`, reboot, verify
   - merge the old root: `pvcreate /dev/vda3; vgextend pool /dev/vda3; lvextend -l +100%FREE /dev/pool/root; resize2fs /dev/pool/root`
   - drop the fallback entry: `NIXOS_INSTALL_BOOTLOADER=1 /run/current-system/bin/switch-to-configuration boot`

WARNING: hardcoded for mos-eisley (/dev/vda, 5.8.11.25, GRUB index 2).
Check `lsblk`, the IP and `grep '^menuentry' /mnt/boot/grub/grub.cfg` first.
