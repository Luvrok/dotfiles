{ lib, username, ... }:

{
  services.greenclip.enable = true;
  systemd.services.greenclip.serviceConfig.User = "${username}";
  # x11 only: the x session wrapper starts this target, sway doesn't.
  # sway keeps its history with cliphist
  systemd.user.services.greenclip.wantedBy = lib.mkForce [ "nixos-fake-graphical-session.target" ];
}
