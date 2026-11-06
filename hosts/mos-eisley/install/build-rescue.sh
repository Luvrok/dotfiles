#!/bin/bash
# busybox + dropbear + fs/partition tools; virtio/ext4 в ubuntu-ядре builtin
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq busybox-static dropbear-bin kexec-tools cpio util-linux e2fsprogs gdisk >/dev/null

R=/root/rescue/root
rm -rf /root/rescue
mkdir -p "$R"/{bin,etc,root/.ssh,dev,proc,sys,run,tmp,var/log,lib64,lib/x86_64-linux-gnu,usr/lib/x86_64-linux-gnu,usr/bin,usr/sbin}

cp /bin/busybox "$R/bin/busybox"
# busybox --install делает ссылки на путь сборки; в initramfs его нет
for a in $("$R/bin/busybox" --list); do
  [ "$a" = busybox ] || ln -sf /bin/busybox "$R/bin/$a"
done

copy() {
  local f lib
  for f in "$@"; do
    cp --parents -L "$f" "$R/"
    ldd "$f" 2>/dev/null | awk '/=> \// { print $3 } /^[[:space:]]*\/.*ld-linux/ { print $1 }' \
      | while read -r lib; do
          [ -n "$lib" ] && cp --parents -L "$lib" "$R/"
        done
  done
}

copy /usr/sbin/dropbear /usr/bin/dropbearkey \
     /usr/sbin/e2fsck /usr/sbin/resize2fs /usr/sbin/sfdisk /usr/sbin/sgdisk /usr/sbin/blkid
cp --parents -L /lib64/ld-linux-x86-64.so.2 "$R/"

printf 'root:x:0:0:root:/root:/bin/sh\n' > "$R/etc/passwd"
printf 'root:x:0:\n' > "$R/etc/group"
printf 'root::0:0:99999:7:::\n' > "$R/etc/shadow"
chmod 600 "$R/etc/shadow"
printf 'passwd: files\ngroup: files\nhosts: files dns\n' > "$R/etc/nsswitch.conf"
printf 'nameserver 8.8.8.8\n' > "$R/etc/resolv.conf"
printf '127.0.0.1 localhost\n' > "$R/etc/hosts"
mkdir -p "$R/etc/dropbear"
chmod 700 "$R/etc/dropbear"
: > "$R/var/log/wtmp"
: > "$R/var/log/lastlog"

cat > "$R/etc/authorized_keys" <<'KEY'
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard
KEY

cat > "$R/init" <<'INIT'
#!/bin/busybox sh
export PATH=/bin:/usr/bin:/usr/sbin

mount -t proc proc /proc
mount -t sysfs sysfs /sys
mount -t devtmpfs devtmpfs /dev
mkdir -p /dev/pts /dev/shm
mount -t devpts devpts /dev/pts
mount -t tmpfs tmpfs /dev/shm
mount -t tmpfs tmpfs /run
hostname rescue

ip link set lo up
IFACE=
for d in /sys/class/net/*; do n=${d##*/}; [ "$n" = lo ] || IFACE=$n; done
ip link set "$IFACE" up
if grep -q 'rescue_dhcp' /proc/cmdline 2>/dev/null; then
  udhcpc -i "$IFACE" -q -n
else
  ip addr add 5.8.11.25/26 dev "$IFACE"
  ip route add default via 5.8.11.1 dev "$IFACE"
fi

mkdir -p /root/.ssh /etc/dropbear
chmod 700 /root/.ssh /etc/dropbear
cp /etc/authorized_keys /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
/usr/sbin/dropbear -R -p 22 -P /run/dropbear.pid -E
sleep 1
if [ -f /run/dropbear.pid ] && kill -0 "$(cat /run/dropbear.pid)" 2>/dev/null; then
  echo "rescue: ssh ready" > /dev/kmsg
else
  echo "rescue: ssh did not start, rebooting" > /dev/kmsg
  sleep 2
  reboot -f
fi

# если ssh не поднялся, через 10 минут вернуться в старую систему
(
  idle=0
  while :; do
    sleep 60
    if awk '$4 == "01" && $2 ~ /:0016$/ { f = 1 } END { exit !f }' /proc/net/tcp /proc/net/tcp6 2>/dev/null; then
      idle=0
    else
      idle=$((idle + 1))
      [ "$idle" -ge 10 ] && { echo "rescue: no ssh, rebooting" > /dev/kmsg; reboot -f; }
    fi
  done
) &

while true; do sleep 3600; done
INIT
chmod 755 "$R/init"

cd "$R"
find . -print0 | cpio --null -o --format=newc 2>/dev/null | gzip -9 > /root/rescue/initrd.gz
ls -lh /root/rescue/initrd.gz
