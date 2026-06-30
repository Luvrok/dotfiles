{ username, ... }:

{
  enable = true;
  user = "${username}";
  openDefaultPorts = true;

  dataDir = "/home/${username}/.config/syncthing";
  configDir = "/home/${username}/.config/syncthing";
}
