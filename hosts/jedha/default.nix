{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./network.nix
    ./navidrome.nix
    ./syncthing.nix
    ./yggdrasil.nix
    ./qbittorrent.nix
    ./audiobookshelf.nix
    ./glances.nix
    ./anki.nix
  ];

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
    "d /var/lib/media/books 2775 audiobookshelf media -"
    "d /var/lib/media/books/data 2775 audiobookshelf media -"
  ];

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBgLYyw9OjtzpBqHkmEXr0J9iDjGBInUG9YC7CoOIlEs tunneluser@barnard"
  ];

  users.users.jedha = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "nopassword";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBgLYyw9OjtzpBqHkmEXr0J9iDjGBInUG9YC7CoOIlEs tunneluser@barnard"
    ];
  };

  environment.etc."nixos".source = ./.;
  system.activationScripts.copyConfig.text = ''
    rm -rf /root/nixos-config
    mkdir -p /root
    cp -rT ${./../..} /root/nixos-config
    chown -R root:root /root/nixos-config
  '';

  environment.systemPackages = with pkgs; [
    vim
    neovim
    htop
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
  ];

  system.stateVersion = "25.11";
}
