# systemd-networkd + resolved with Quad9. Interfaces come from galaxy.network.interfaces.
{ config, lib, ... }:

let
  inherit (lib) mkOption types;
  cfg = config.galaxy.network;

  iface = types.submodule {
    options = {
      match = mkOption {
        type = types.attrsOf types.str;
        description = "networkd [Match] section, e.g. { Name = \"wlan0\"; }.";
      };
      dhcp = mkOption {
        type = types.bool;
        default = true;
        description = "DHCP with DNS-over-TLS to Quad9. false = static only.";
      };
      metric = mkOption {
        type = types.int;
        default = 20;
        description = "DHCPv4 route metric.";
      };
      address = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
      gateway = mkOption {
        type = types.nullOr types.str;
        default = null;
      };
    };
  };

  mkNetwork =
    i:
    {
      matchConfig = i.match;
    }
    // lib.optionalAttrs i.dhcp {
      networkConfig = {
        DHCP = "yes";
        DNS = cfg.dns;
        IPv6AcceptRA = "yes";
        DNSOverTLS = true;
      };
      dhcpV4Config = {
        UseDNS = false;
        RouteMetric = i.metric;
      };
    }
    // lib.optionalAttrs (!i.dhcp) { dns = cfg.dns; }
    // lib.optionalAttrs (i.address != null) { address = [ i.address ]; }
    // lib.optionalAttrs (i.gateway != null) {
      routes = [
        {
          Gateway = i.gateway;
          GatewayOnLink = true;
        }
      ];
    };
in
{
  options.galaxy.network = {
    enable = lib.mkEnableOption "networkd, resolved and a firewall";

    # Full resolved/networkd setup used by barnard, alderaan and jedha.
    # VPS hosts only get networkd + resolved with defaults.
    client.enable = lib.mkEnableOption "the resolved setup with Quad9 fallback and no NetworkManager";

    wifi.enable = lib.mkEnableOption "iwd";

    dns = mkOption {
      type = types.listOf types.str;
      default = [
        "9.9.9.9"
        "149.112.112.112"
        "2620:fe::fe"
        "2620:fe::9"
      ];
    };

    interfaces = mkOption {
      type = types.attrsOf iface;
      default = { };
      description = "systemd.network.networks, keyed by unit name.";
    };

    tcpPorts = mkOption {
      type = types.listOf types.port;
      default = [ ];
    };

    udpPorts = mkOption {
      type = types.listOf types.port;
      default = [ ];
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        networking = {
          useNetworkd = true;
          firewall = {
            enable = true;
            allowPing = true;
            allowedTCPPorts = cfg.tcpPorts;
            allowedUDPPorts = cfg.udpPorts;
          };
        };

        services.resolved.enable = true;

        systemd.network = {
          enable = true;
          networks = lib.mapAttrs (_: mkNetwork) cfg.interfaces;
        };
      }

      (lib.mkIf cfg.client.enable {
        networking = {
          useDHCP = false;
          usePredictableInterfaceNames = true;
          networkmanager.enable = false;
          nameservers = cfg.dns;
        };

        services.resolved.settings.Resolve = {
          DNSSEC = false;
          DNSOverTLS = false;
          Domains = [ "~." ];
          LLMNR = false;
          FallbackDNS = cfg.dns;
        };

        systemd.network.wait-online.enable = false;
      })

      (lib.mkIf (!cfg.client.enable) {
        networking.wireless.enable = false;
        networking.enableIPv6 = true;
        systemd.network.wait-online.anyInterface = true;
      })

      (lib.mkIf cfg.wifi.enable {
        networking.wireless.iwd = {
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
      })
    ]
  );
}
