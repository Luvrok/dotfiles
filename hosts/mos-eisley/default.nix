# VPS in Russia: nginx on :443 (SNI split between sites and xray), xray portal.
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  galaxy.host.user = "kessel";
  galaxy.profiles.vps.enable = true;

  galaxy.services.nginx.enable = true;
  galaxy.services.xray = {
    legacyConfig = ./xray.json; # remove once the xray/* secrets are in sops
    role = "portal";
    # Behind nginx: take what nginx doesn't claim.
    # portal = { listen = "127.0.0.1"; port = 10443; };
  };

  galaxy.network = {
    interfaces."10-eth" = {
      match.Name = "ens3";
      dhcp = false;
      address = "192.168.0.5/32";
      gateway = "192.168.0.1";
    };
    tcpPorts = [
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
    udpPorts = [
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

  services.getty.autologinUser = "root";
}
