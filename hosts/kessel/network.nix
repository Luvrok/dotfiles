{ ... }:

let
  # the public address lives in a git-crypt'd file, see address.nix
  net = import ./address.nix;
in
{
  # DNS: resolved -> dnscrypt-proxy -> DoH
  dotfiles.doh.enable = true;

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
      ];
      allowedUDPPorts = [ ];
    };
  };

  systemd.network = {
    enable = true;
    wait-online.anyInterface = true;

    networks."10-eth" = {
      matchConfig.Name = "enp0s4";
      address = [ "${net.address}/${toString net.prefixLength}" ];
      routes = [
        {
          Gateway = net.gateway;
          GatewayOnLink = true;
        }
      ];
    };
  };

  # Prefer IPv4 over IPv6 (writes /etc/gai.conf)
  # https://popov.wtf/how-to-prioritize-ipv4-over-ipv6-in-linux
  networking.getaddrinfo.precedence."::ffff:0:0/96" = 100;
}
