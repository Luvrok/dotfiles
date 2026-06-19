{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./yggdrasil.nix
    ./syncthing.nix
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
  };

  time.timeZone = "Europe/Amsterdam";
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
      4533
      4544
      4545
      8129
      8208
      8443
      8448
      21027
      22000
      22067
      22070
      42853
    ];
    allowedUDPPorts = [
      8443
      22000
      22067
      22070
      42853
    ];
    allowPing = true;
  };

  systemd.network.networks."10-eth" = {
    matchConfig.MACAddress = "bc:24:11:36:06:8e";
    address = [ "45.135.180.21/32" ];
    routes = [
      {
        Gateway = "45.135.180.1";
        GatewayOnLink = true;
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

  networking.enableIPv6 = true;

  # https://popov.wtf/how-to-prioritize-ipv4-over-ipv6-in-linux
  environment.etc."gai.conf".text = ''
    precedence ::ffff:0:0/96  100
  '';

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
    busybox
  ];

  services.vnstat.enable = true;
  system.stateVersion = "25.11";
}
