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
      expect

      # --- development ---
      buildPackages.gnumake
      cargo
      clang-tools
      cmake
      gcc
      jq
      nodejs
      rustc
      tree-sitter
      yajl
      lazygit
      typst
      python3

      # --- go ---
      delve
      go
      golangci-lint
      goimports-reviser
      gotools
      gopls
      gofumpt

      # --- formatters ---
      beautysh
      nixfmt
      prettierd
      sql-formatter
      stylua
      typstyle

      # --- lsp ---
      bash-language-server
      shellcheck # bashls lints with it
      lua-language-server
      marksman
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
      wireshark

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
      calibre # ebook convert
      glances
      acl
      inotify-info
      age
      sops
      sshfs
      pciutils
      nsxiv
      zathura

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
      librsvg
      slop
      st
      xclip
      (tesseract.override { enableLanguages = [ "eng" "rus" ]; })
      xcolor
      xcursorthemes
      xdotool
      xdpyinfo
      xinit
      xkb-switch
      xset
      xsetroot
      xsettingsd
      xwininfo
      xwinwrap
      xwallpaper
      libxrandr
      xsel

      # --- apps ---
      aseprite
      chromium
      discord
      feh
      libreoffice
      obsidian
      pavucontrol
      qbittorrent
      gopeed
      songrec
      spotify
      feishin
      syncthing
      telegram-desktop
      veracrypt
      graphviz
      xdot
      worldpainter
      typstwriter
      anki

      # --- games ---
      prismlauncher

      # --- android ---
      adbfs-rootless # mount android phone as a folder
      android-tools # connect phone/camera

      # --- live-usb ---
      woeusb

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
      home-manager
      nh
    ])
    ++ (with pkgs-pinned; [
    ]);
}
