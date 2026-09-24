{ config, lib, ... }:

{
  options.galaxy.profiles.laptop.enable = lib.mkEnableOption "the laptop profile" // {
    default = config.galaxy.host.isLaptop;
    defaultText = "config.galaxy.host.isLaptop";
  };

  config = lib.mkIf config.galaxy.profiles.laptop.enable {
    galaxy.network.wifi.enable = lib.mkDefault true;
  };
}
