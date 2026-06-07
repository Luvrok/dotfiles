{ username, ... }:

{
  enable = true;
  user = "${username}";
  openDefaultPorts = true;
  all_proxy = "socks5://localhost:10808";

  dataDir = "/home/${username}/.config/syncthing";
  configDir = "/home/${username}/.config/syncthing";
}
