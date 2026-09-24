{ pkgs, ... }:

{
  imports = [
    # ./disk-config.nix
    ./hardware-configuration.nix
    ./nginx.nix
  ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
  };

  services.getty.autologinUser = "root";

  time.timeZone = "Europe/Moscow";
  i18n.defaultLocale = "en_GB.UTF-8";

  networking.hostName = "mos-eisley";
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
      4110
      4533
      4545
      5389
      8129
      8130
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
      4110
      4533
      4545
      5389
      8129
      8130
      8208
      8443
      8448
      21027
      22000
      22067
      22070
      42853
    ];
    allowPing = true;
  };

  systemd.network.networks."10-eth" = {
    matchConfig.Name = "ens3";
    address = [ "192.168.0.5/32" ];
    routes = [
      {
        Gateway = "192.168.0.1";
        GatewayOnLink = true;
      }
    ];
    dns = [
      "9.9.9.9"
      "149.112.112.112"
      "2620:fe::fe"
      "2620:fe::9"
    ];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGifq/+thCOHb5sXkWRQl9RXtddSAemKErUkdngEa7sJ dash@dash"
  ];

  users.users.kessel = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "nopassword";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGifq/+thCOHb5sXkWRQl9RXtddSAemKErUkdngEa7sJ dash@dash"
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
  ];

  services.vnstat.enable = true;
  system.stateVersion = "26.05";
}
