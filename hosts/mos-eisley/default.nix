{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [
    # ./disk-config.nix
    ./hardware-configuration.nix
    ./network.nix
    ./nginx.nix
  ];

  dotfiles.small-disk.enable = true;

  # the virtual disk is virtio; disko puts the device into grub.devices
  boot.loader.grub.enable = true;

  # 1 GB of ram
  swapDevices = [
    {
      device = "/swapfile";
      size = 2048;
    }
  ];

  sops.defaultSopsFile = ../../secrets/mos-eisley.yaml;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  services.getty.autologinUser = "root";

  time.timeZone = "Europe/Moscow";
  i18n.defaultLocale = "en_GB.UTF-8";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGifq/+thCOHb5sXkWRQl9RXtddSAemKErUkdngEa7sJ dash@dash"
  ];

  environment.etc."nixos".source = ./.;
  system.activationScripts.copyConfig.text = ''
    rm -rf /root/nixos-config
    mkdir -p /root
    cp -rT ${./../..} /root/nixos-config
    chown -R 0:0 /root/nixos-config
  '';

  services.xray = {
    enable = true;
    settingsFile = ./xray.json;
  };

  systemd.services.xray = lib.mkIf config.services.xray.enable {
    serviceConfig = {
      RuntimeDirectory = "xray";
      RuntimeDirectoryMode = "0750";
      ReadWritePaths = [ "/run/xray" ];

      MemoryMax = "512M";
      Restart = "always";
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    jq
    htop
    curl
    wget
    git
    btop
    xray
    vnstat
    dig
    git-crypt
    nh
    iperf
    mtr
    busybox
    age
    sops
    gcc
  ];

  services.vnstat.enable = true;
  system.stateVersion = "26.05";
}
