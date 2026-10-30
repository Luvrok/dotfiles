{ ... }:

{
  # DNS: resolved -> dnscrypt-proxy -> DoH
  imports = [ ../../modules/doh ];

  networking = {
    hostName = "mos-eisley";
    useNetworkd = true;
    wireless.enable = false;
    enableIPv6 = true;

    firewall = {
      enable = true;
      allowPing = true;
      # only what's reachable from outside. nginx and the xray tunnel
      # inbounds talk over 127.0.0.1, and lo is trusted anyway
      allowedTCPPorts = [
        22
        80
        443
      ];
    };
  };

  systemd.network = {
    enable = true;
    wait-online.anyInterface = true;

    networks."10-eth" = {
      matchConfig.Name = "ens3";
      address = [ "192.168.0.5/32" ];
      routes = [
        {
          Gateway = "192.168.0.1";
          GatewayOnLink = true;
        }
      ];
    };
  };

  # Prefer IPv4 over IPv6 (writes /etc/gai.conf)
  # https://popov.wtf/how-to-prioritize-ipv4-over-ipv6-in-linux
  networking.getaddrinfo.precedence."::ffff:0:0/96" = 100;
}
