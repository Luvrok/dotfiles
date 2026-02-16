{ pkgs, pkgs-pinned, ... }:


{
  environment.systemPackages = (with pkgs; [
    # --- dependencies ---
    glibc
    glib
    gcc
    cmake
    buildPackages.gnumake
    gamescope
    tor
    cargo # need for nixd lsp build
    python312
    nodejs_25
    chromium # need for via qmk
    monero-cli # need for monero-gui for some reason cant sync without monero-cli

    # --- xorg ---
    libxcvt
    xkb-switch
    xdotool
    xsetroot
    xcursorthemes
    xset
    xsettingsd
    xclip
    xcolor
    xwinwrap
    xinit
    xdg-desktop-portal
    dmenu
    j4-dmenu-desktop
    st
    dwmblocks

    # --- basic utilities ---
    bash
    lsof
    coreutils
    wget
    curl
    man
    unzip
    unrar
    p7zip
    zip
    htop
    iotop
    killall
    dig
    nmap
    inetutils # telnet, ftp, hostname, etc
    usbutils
    bc
    powertop
    lshw
    mesa-demos
    vnstat
    testdisk
    feh
    pciutils
    qpwgraph
    e2fsprogs
    acpi
    util-linux
    calcurse # calendar in terminal
    parted
    efibootmgr
    grub2
    pacman
    ripgrep
    gnugrep
    gawk
    fd
    ethtool
    dnsmasq
    tcpdump
    procps
    file
    alsa-utils
    ddcutil
    home-manager

    # --- networking ---
    openssl
    iptables
    networkmanager
    # xray
    shadowsocks-rust

    # --- system tools ---
    libnotify
    jq

    # --- multimedia ---
    ffmpeg

    # --- apps ---
    qbittorrent
    obsidian
    wasabiwallet
    syncthing
    spotify
    libreoffice
    librewolf
    veracrypt
    monero-gui
    telegram-desktop
    discord
    heroic

    # --- talking ---
    # discord
    element-desktop
    element-call
    irssi

    # --- games ---
    prismlauncher

    # --- hardware ---
    dualsensectl # CLI interface for controlling Sony Dualsense controllers
    # openrgb-with-all-plugins

    # --- android ---
    android-tools
    adbfs-rootless
    jmtpfs

    # --- live usb ---
    woeusb
    unetbootin

    # --- testing system ---
    vrrtest
    stress-ng
    lksctp-tools
    evtest
    xev

    # --- go ---
    go
    gopls
    delve
    golangci-lint
    goimports-reviser
    gotools

    # --- temporary ---
    pavucontrol
  ]) ++ (with pkgs-pinned; [
  ]);
}
