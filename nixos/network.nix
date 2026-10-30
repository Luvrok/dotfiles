{ username, ... }:

let
  # DNS comes only from modules/doh.nix, so DNS servers pushed by DHCP/RA
  # (the ISP's, spoofable) are ignored.
  # Lower metric wins: ethernet is preferred over wifi when both are up.
  mkLink = name: metric: {
    matchConfig.Name = name;

    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };

    dhcpV4Config = {
      UseDNS = false;
      RouteMetric = metric;
    };

    dhcpV6Config.UseDNS = false;

    ipv6AcceptRAConfig = {
      UseDNS = false;
      RouteMetric = metric;
    };
  };
in
{
  imports = [
    ../modules/doh
    ../modules/doh/local-doh.nix
  ];

  networking = {
    hostName = "${username}";

    useNetworkd = true;
    useDHCP = false;
    usePredictableInterfaceNames = true;
    networkmanager.enable = false;

    # the servers by name (/etc/hosts): ssh root@jedha, sapply-remote, the
    # hyprland nix menu. jedha by wifi like jedha-tunnel.nix, its eth is .216
    hosts = {
      "192.168.0.217" = [ "jedha" ];
      "195.19.202.21" = [ "mos-eisley" ];
      "45.38.20.187" = [ "kessel" ];
    };

    firewall = {
      enable = true;
      trustedInterfaces = [ "virbr0" ];
      allowPing = true;
      allowedTCPPorts = [
        22000 # syncthing
        51413
        61208
      ];
      allowedUDPPorts = [
        21027 # syncthing discovery
        51413
        22000 # syncthing
      ];
    };

    # iwd only authenticates; addresses and routes come from networkd
    wireless.iwd = {
      enable = true;
      settings = {
        Settings.AutoConnect = true;
        General = {
          AddressRandomization = "network";
          AddressRandomizationRange = "full";
          EnableNetworkConfiguration = false;
          RoamRetryInterval = 10;
        };
        Network.EnableIPv6 = true;
      };
    };
  };

  systemd.network = {
    enable = true;
    wait-online.enable = false;

    networks = {
      "10-eth" = mkLink "enp14s0" 100;
      "20-wifi" = mkLink "wlan0" 600;
    };
  };
}
