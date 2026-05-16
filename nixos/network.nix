{ username, ... }:

{
  networking = {
    hostName = "${username}";

    useNetworkd = true;
    useDHCP = false;
    usePredictableInterfaceNames = true;
    networkmanager.enable = false;

    nameservers = [
      "9.9.9.9"
      "149.112.112.112"
      "2620:fe::fe"
      "2620:fe::9"
    ];

    firewall = {
      enable = true;
      trustedInterfaces = [ "virbr0" ];
      allowPing = true;
      allowedTCPPorts = [
        7777
        8384
        22000 # syncthing
        61208
      ];
      allowedUDPPorts = [
        7777
        21027 # syncthing discovery
        22000 # syncthing
      ];
    };

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

        Network = {
          EnableIPv6 = true;
          RoutePriorityOffset = 300;
        };
      };
    };
  };

  # systemd-resolved
  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNSSEC = false;
      DNSOverTLS = true;
      Domains = [ "~." ];
      LLMNR = false;
      FallbackDNS = [
        "9.9.9.9"
        "149.112.112.112"
        "2620:fe::fe"
        "2620:fe::9"
      ];
    };
  };

  # systemd-networkd
  systemd.network = {
    enable = true;
    wait-online.enable = false;

    networks = {
      "10-eth" = {
        matchConfig.Name = "enp14s0";

        networkConfig = {
          DHCP = "yes";
          DNS = [
            "9.9.9.9"
            "149.112.112.112"
            "2620:fe::fe"
            "2620:fe::9"
          ];
          IPv6AcceptRA = "yes";
          DNSOverTLS = true;
        };

        dhcpV4Config = {
          UseDNS = false;
          RouteMetric = 20;
        };
      };

      "20-wifi" = {
        matchConfig.Name = "wlan0";

        networkConfig = {
          DHCP = "yes";
          DNS = [
            "9.9.9.9"
            "149.112.112.112"
            "2620:fe::fe"
            "2620:fe::9"
          ];
          IPv6AcceptRA = "yes";
          DNSOverTLS = true;
        };

        dhcpV4Config = {
          UseDNS = false;
          RouteMetric = 10;
        };
      };
    };
  };
}
