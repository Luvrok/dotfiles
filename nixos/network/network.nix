{ username, ... }:

{
  networking = {
    hostName = "${username}";

    networkmanager = {
      enable = false;
    };

    firewall = {
      allowedTCPPorts = [
        7777
        8384
        22000
      ];
      allowedUDPPorts = [
        7777
        21027
        22000
      ];
    };
  };

  systemd.network.wait-online.enable = false;

  services.resolved.enable = true;

  systemd.network.networks."10-eth" = {
    matchConfig.Name = "enp14s0";
    networkConfig.DHCP = "ipv4";
  };

  systemd.network.networks."20-wifi" = {
    matchConfig.Name = "wlan0";
    networkConfig.DHCP = "ipv4";
  };
}
