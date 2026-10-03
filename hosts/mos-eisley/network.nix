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
