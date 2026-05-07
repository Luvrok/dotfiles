{
  pkgs,
  pkgs-pinned,
  ...
}:

{
  environment.systemPackages =
    (with pkgs; [
      # --- base ---
      bash
      bat
      bc
      coreutils
      fd
      file
      gawk
      gnugrep
      ripgrep
      wget

      # --- development ---
      buildPackages.gnumake
      cargo
      clang-tools
      cmake
      gcc
      go
      golangci-lint
      goimports-reviser
      gotools
      jq
      nodejs
      rustc
      tree-sitter
      yajl
      lazygit
      typst

      # --- formatters ---
      beautysh
      gofumpt
      nixfmt
      prettierd
      sql-formatter
      stylua
      typstyle

      # --- lsp ---
      bash-language-server
      gopls
      lua-language-server
      marksman
      nil
      nixd
      sqls
      taplo
      typescript-language-server
      vscode-langservers-extracted
      yaml-language-server
      tinymist

      # --- networking ---
      dig
      dnsmasq
      ethtool
      inetutils
      iperf
      busybox
      iptables
      mtr
      networkmanager
      nmap
      openssl
      shadowsocks-rust
      tcpdump
      tor
      v2rayn

      # --- system ---
      acpi
      alsa-utils
      ddcutil
      e2fsprogs
      efibootmgr
      glib
      glibc
      grub2
      htop
      iotop
      killall
      libnotify
      lshw
      lsof
      pacman
      parted
      powertop
      procps
      sysstat
      util-linux
      vnstat

      # --- archives ---
      p7zip
      unrar
      unzip
      zip

      # --- media ---
      ffmpeg-full
      losslesscut-bin
      mesa-demos
      pulseaudioFull
      qpwgraph
      v4l-utils

      # --- xorg ---
      better-swallow
      dmenu
      dwmblocks
      j4-dmenu-desktop
      libxcvt
      slop
      st
      xclip
      xcolor
      xcursorthemes
      xdg-desktop-portal
      xdotool
      xdpyinfo
      xinit
      xkb-switch
      xset
      xsetroot
      xsettingsd
      xwininfo
      xwinwrap

      # --- apps ---
      aseprite
      chromium
      discord
      feh
      libreoffice
      monero-cli
      monero-gui
      obsidian
      pavucontrol
      qbittorrent
      songrec
      spotify
      syncthing
      telegram-desktop
      veracrypt
      wasabiwallet
      graphviz
      xdot
      worldpainter
      typstwriter

      # --- tui ---
      irssi

      # --- games ---
      gamescope
      prismlauncher

      # --- android ---
      adbfs-rootless
      android-tools
      jmtpfs

      # --- live-usb ---
      unetbootin
      woeusb

      # --- hardware ---
      # openrgb-with-all-plugins

      # --- testing ---
      evtest
      lksctp-tools
      rocmPackages.rocminfo
      rocmPackages.rocm-smi
      stress-ng
      testdisk
      vrrtest
      xev

      # --- management ---
      dualsensectl
      home-manager
      nh

      # --- debug ---
      delve
    ])
    ++ (with pkgs-pinned; [
    ]);
}
