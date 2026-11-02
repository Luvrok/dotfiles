{ username, ... }:

{
  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

  services.syncthing = {
    enable = true;
    user = "${username}";
    openDefaultPorts = true;

    dataDir = "/home/${username}/.config/syncthing";
    configDir = "/home/${username}/.config/syncthing";
  };
}
