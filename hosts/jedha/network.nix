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
      allowPing = true;
      allowedTCPPorts = [
        22
        80
        443
        4533
        5201
        8129
        8384
        8448
        22000 # syncthing
        42853
      ];
      allowedUDPPorts = [
        21027 # syncthing discovery
        22000 # syncthing
        42853
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
        matchConfig.MACAddress = "bc:c3:42:af:59:e6";

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

        address = [ "192.168.0.216/24" ];
        routes = [
          {
            Gateway = "192.168.0.1";
            GatewayOnLink = true;
          }
        ];
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

        address = [ "192.168.0.217/24" ];
        routes = [
          {
            Gateway = "192.168.0.1";
            GatewayOnLink = true;
          }
        ];
      };
    };
  };
}
