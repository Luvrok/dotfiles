{ username, ... }:

{
  services.greenclip.enable = true;
  systemd.services.greenclip.serviceConfig.User = "${username}";
}
