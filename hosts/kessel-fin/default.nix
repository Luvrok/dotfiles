{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

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
    max-jobs = 1;
    cores = 1;
    auto-optimise-store = true;
  };

  time.timeZone = "Europe/Helsinki";
  i18n.defaultLocale = "en_GB.UTF-8";

  networking.hostName = "kessel";
  networking.wireless.enable = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  systemd.network.enable = true;
  systemd.network.wait-online.anyInterface = true;
  services.resolved.enable = true;
  networking.useNetworkd = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      22
      80
      443
      8448
    ];
    allowPing = true;
  };

  systemd.network.networks."10-eth" = {
    matchConfig.MACAddress = "00:cd:6c:68:d6:29";
    address = [ "5.181.181.60/24" ];
    routes = [
      {
        Gateway = "5.181.181.1";
      }
    ];
    dns = [ "9.9.9.9" ];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard"
  ];

  users.users.kessel = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "nopassword";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard"
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

  systemd.services.xray = {
    serviceConfig = {
      RuntimeDirectory = "xray";
      RuntimeDirectoryMode = "0750";
      ReadWritePaths = [ "/run/xray" ];

      RuntimeMaxSec = "30min";
      Restart = "always";
    };
  };

  environment.systemPackages = with pkgs; [
    vim
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
  ];

  services.vnstat.enable = true;
  system.stateVersion = "25.11";
}
