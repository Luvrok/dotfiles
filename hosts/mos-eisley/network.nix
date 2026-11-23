{ ... }:

{
  # DNS: resolved -> dnscrypt-proxy -> DoH
  dotfiles.doh.enable = true;

  # the ru dpi drops most of telegram's api addresses (149.154.166.110,
  # 149.154.175.50 time out), this one answers. the bot polls it by name, so
  # a plain hosts entry keeps the certificate check intact. if long polling
  # starts timing out, try another api.telegram.org address here
  networking.hosts."149.154.167.220" = [ "api.telegram.org" ];

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
      address = [ "5.8.11.25/26" ];
      routes = [
        {
          Gateway = "5.8.11.1";
          GatewayOnLink = true;
        }
      ];
    };
  };

  # Prefer IPv4 over IPv6 (writes /etc/gai.conf)
  # https://popov.wtf/how-to-prioritize-ipv4-over-ipv6-in-linux
  networking.getaddrinfo.precedence."::ffff:0:0/96" = 100;
}
