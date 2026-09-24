# Every host.
{ config, lib, ... }:

{
  options.galaxy.profiles.base.enable = lib.mkEnableOption "the base profile" // {
    default = true;
  };

  config = lib.mkIf config.galaxy.profiles.base.enable {
    time.timeZone = lib.mkDefault "Europe/Moscow";
    services.vnstat.enable = lib.mkDefault true;
    galaxy.network.enable = lib.mkDefault true;
    system.stateVersion = lib.mkDefault "26.05";
  };
}
