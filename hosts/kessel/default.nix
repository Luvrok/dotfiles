# VPS in the Netherlands: xray portal, tunnels jedha's ports.
{
  imports = [
    ./hardware-configuration.nix
    ./disk-config.nix
  ];

  time.timeZone = "Europe/Amsterdam";

  galaxy.profiles.vps.enable = true;

  galaxy.services.xray = {
    legacyConfig = ./xray.json; # remove once the xray/* secrets are in sops
    role = "portal";
    # portal = { dest = "..."; serverNames = [ "..." ]; users = [ "barnard" "phone" ]; };
  };

  galaxy.network.interfaces."10-eth" = {
    match.Name = "enp0s4";
    dhcp = false;
    address = "45.38.20.187/32";
    gateway = "100.195.242.189";
  };
}
