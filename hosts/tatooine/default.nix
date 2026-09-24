# VPS in the Netherlands: xray portal, tunnels jedha's ports.
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  time.timeZone = "Europe/Amsterdam";

  galaxy.host.user = "kessel";
  galaxy.profiles.vps.enable = true;

  galaxy.services.xray = {
    legacyConfig = ./xray.json; # remove once the xray/* secrets are in sops
    role = "portal";
  };

  galaxy.network.interfaces."10-eth" = {
    match.Name = "ens18";
    dhcp = false;
    address = "78.17.70.36/32";
    gateway = "78.17.70.1";
  };

  services.getty.autologinUser = "root";
}
