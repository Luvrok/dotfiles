# ~/.local/media: sounds for scripts/deploy, the fastfetch picture.
{ config, lib, ... }:

{
  config = lib.mkIf config.galaxy.desktop.session.enable {
    galaxy.files.home = config.galaxy.lib.linkTree ".local/media" ./media;
  };
}
