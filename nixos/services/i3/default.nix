{ ... }:

{
  services.xserver.windowManager.i3 = {
    enable = true;
    configFile = ./config;
    extraPackages = [ ];
  };
}
