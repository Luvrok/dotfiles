{ lib, ... }:

{
  # x11 only: the x session wrapper starts this target, sway doesn't.
  # sway runs gammastep instead
  systemd.user.services.redshift.Install.WantedBy = lib.mkForce [
    "nixos-fake-graphical-session.target"
  ];

  services.redshift = {
    enable = true;
    settings.redshift = {
      brightness-day = "1";
      brightness-night = "1";
      location-provider = "manual";
      adjustment-method = "vidmode";
      transition = "1";
    };
    temperature = {
      day = 5000;
      night = 4000;
    };
    latitude = "59.9343";
    longitude = "30.3351";
  };
}
