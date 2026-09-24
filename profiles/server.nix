# Home server (jedha): media services behind the xray tunnel.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  on = lib.mkDefault true;
in
{
  options.galaxy.profiles.server.enable = lib.mkEnableOption "the home server profile";

  config = lib.mkIf config.galaxy.profiles.server.enable {
    galaxy = {
      server.enable = on;
      network.client.enable = on;
      sops = {
        enable = on;
        useHostKey = on;
      };
      services = {
        glances.enable = on;
        syncthing.enable = on;
      };
    };

    environment.systemPackages = with pkgs; [
      neovim
      glances
      openssl
      ranger
      calibre
      tmux
    ];

    # Shared by qbittorrent, navidrome, kavita and syncthing.
    users.groups.media = { };

    systemd.tmpfiles.rules = [
      "d /var/lib/media 2775 root media -"
      "d /var/lib/media/downloads 2775 root media -"
      "d /var/lib/media/music 2775 root media -"
      "d /var/lib/media/books 2775 root media -"
      "d /var/lib/media/books/data 2775 root media -"
    ];
  };
}
