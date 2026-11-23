{ pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./network.nix
    ./navidrome.nix
    ./syncthing.nix
    ./qbittorrent.nix
    ./glances.nix
    ./anki.nix
    ./kavita.nix
    ./koito.nix
    ./libretranslate
    ./kiss-worker.nix
    ./subtitle-translator
    ./obsidian-livesync.nix
    ./rsshub.nix
    ./polymarket.nix
    ./chair-rental-bot.nix
    inputs.dispatch.nixosModules.default
    inputs.chair-rental-bot.nixosModules.default
  ];

  services.dispatch = {
    enable = true;
    port = 8180;
    settings = {
      fetch.proxy = "http://127.0.0.1:10808";
      # RSSHub runs on 127.0.0.1:1200. Loopback requests bypass the proxy;
      # this flag only lifts the SSRF guard for local feed URLs.
      fetch.allow_private_networks = true;
    };
  };

  # The old Miniflux port 8180 is already exposed through xray on mos-eisley;
  # starting after the tunnel and RSSHub avoids a noisy first poll.
  systemd.services.dispatch.after = [
    "network-online.target"
    "xray.service"
    "rsshub.service"
  ];
  systemd.services.dispatch.wants = [
    "network-online.target"
    "xray.service"
    "rsshub.service"
  ];

  # The Miniflux service is gone; the secret file is still used by polymarket
  # for its ntfy topic. Do not delete the sops entry.
  sops.secrets."miniflux/admin" = { };

  sops.defaultSopsFile = ../../secrets/barnard.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  services = {
    vnstat.enable = true;

    openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };
  };

  # 4 GB and no swap
  zramSwap.enable = true;

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
  };

  time.timeZone = "Europe/Moscow";
  i18n.defaultLocale = "en_GB.UTF-8";

  users.groups.media = { };

  systemd.tmpfiles.rules = [
    "d /var/lib/media 2775 root media -"
    "d /var/lib/media/downloads 2775 root media -"
    "d /var/lib/media/music 2775 root media -"
    "d /var/lib/media/books 2775 root media -"
    "d /var/lib/media/books/data 2775 root media -"
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBgLYyw9OjtzpBqHkmEXr0J9iDjGBInUG9YC7CoOIlEs tunneluser@barnard"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIn4ANeVS4CR7pGZW1pctYx7RXZtPixdUQnZDfPs7i6V tunneluser@kessel"
  ];

  users.users.jedha = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "nopassword";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBgLYyw9OjtzpBqHkmEXr0J9iDjGBInUG9YC7CoOIlEs tunneluser@barnard"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIn4ANeVS4CR7pGZW1pctYx7RXZtPixdUQnZDfPs7i6V tunneluser@kessel"
    ];
  };

  environment.etc."nixos".source = ./.;
  system.activationScripts.copyConfig.text = ''
    rm -rf /root/nixos-config
    mkdir -p /root
    cp -rT ${./../..} /root/nixos-config
    chown -R root:root /root/nixos-config
  '';

  services.xray = {
    enable = true;
    settingsFile = ./xray.json;
  };

  environment.systemPackages = with pkgs; [
    vim
    neovim
    htop
    jq
    curl
    wget
    git
    btop
    vnstat
    dig
    git-crypt
    nh
    iperf
    mtr
    busybox
    glances
    openssl
    ranger
    # calibre
    age
    sops
    tmux
    chromaprint
  ];

  system.stateVersion = "26.05";
}
