# Home server on an old laptop: media services, published through xray on the VPS hosts.
{
  imports = [ ./hardware-configuration.nix ];

  galaxy.host = {
    isLaptop = true;
    sshKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBgLYyw9OjtzpBqHkmEXr0J9iDjGBInUG9YC7CoOIlEs tunneluser@barnard"
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIn4ANeVS4CR7pGZW1pctYx7RXZtPixdUQnZDfPs7i6V tunneluser@kessel"
    ];
  };

  galaxy.profiles.server.enable = true;

  galaxy.services = {
    navidrome.enable = true;
    kavita.enable = true;
    koito.enable = true;
    anki.enable = true;
    qbittorrent.enable = true;
    libretranslate.enable = true;
    zapret.enable = true;

    xray = {
      enable = true;
      legacyConfig = ./xray.json; # remove once the xray/* secrets are in sops
      role = "bridge";
      # bridge.portals = {
      #   kessel = { address = "45.38.20.187"; serverName = "..."; publicKey = "..."; };
      # };
    };
  };

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  galaxy.network = {
    interfaces = {
      "10-eth" = {
        match.MACAddress = "bc:c3:42:af:59:e6";
        metric = 20;
        address = "192.168.0.216/24";
        gateway = "192.168.0.1";
      };
      "20-wifi" = {
        match.Name = "wlan0";
        metric = 10;
        address = "192.168.0.217/24";
        gateway = "192.168.0.1";
      };
    };
    tcpPorts = [
      22
      80
      443
      4110
      4533
      4545
      5201
      5389
      8129
      8130
      8208
      8384
      8392
      8448
      22000 # syncthing
      42853
    ];
    udpPorts = [
      4110
      4533
      4545
      5201
      5389
      8129
      8130
      8208
      8384
      8392
      8448
      21027 # syncthing discovery
      22000 # syncthing
      42853
    ];
  };
}
