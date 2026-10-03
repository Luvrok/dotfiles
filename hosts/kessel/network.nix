{ ... }:

{
  # DNS: resolved -> dnscrypt-proxy -> DoH
  imports = [ ../../modules/doh ];

  networking = {
    hostName = "kessel";
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
        4533
        4545
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
        8443
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
      matchConfig.Name = "enp0s4";
      address = [ "45.38.20.187/32" ];
      routes = [
        {
          Gateway = "100.195.242.189";
          GatewayOnLink = true;
        }
      ];
    };
  };

  # Prefer IPv4 over IPv6 (writes /etc/gai.conf)
  # https://popov.wtf/how-to-prioritize-ipv4-over-ipv6-in-linux
  networking.getaddrinfo.precedence."::ffff:0:0/96" = 100;
}
