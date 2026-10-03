{ username, ... }:

let
  dnsServers = [
    "9.9.9.9"
    "149.112.112.112"
    "2620:fe::fe"
    "2620:fe::9"
  ];

  mkLink = match: address: metric: {
    matchConfig = match;

    networkConfig = {
      DHCP = "yes";
      IPv6AcceptRA = true;
    };

    address = [ address ];
    routes = [
      {
        Gateway = "192.168.0.1";
        GatewayOnLink = true;
        Metric = metric;
      }
    ];

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
  imports = [ ../../modules/doh ];

  networking = {
    hostName = "${username}";

    useNetworkd = true;
    useDHCP = false;
    usePredictableInterfaceNames = true;
    networkmanager.enable = false;

    firewall = {
      enable = true;
      allowPing = true;
      allowedTCPPorts = [
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
        8291
        8384
        8392
        8448
        22000 # syncthing
        42853
      ];
      allowedUDPPorts = [
        4110
        4533
        4545
        5201
        5389
        8129
        8130
        8208
        8291
        8384
        8392
        8448
        21027 # syncthing discovery
        22000 # syncthing
        42853
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
      "10-eth" = mkLink { MACAddress = "bc:c3:42:af:59:e6"; } "192.168.0.216/24" 100;
      "20-wifi" = mkLink { Name = "wlan0"; } "192.168.0.217/24" 600;
    };
  };
}
