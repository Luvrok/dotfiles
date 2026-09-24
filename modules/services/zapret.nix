# DPI bypass for Discord/YouTube.
{
  config,
  lib,
  inputs,
  ...
}:

let
  cfg = config.galaxy.services.zapret;
in
{
  imports = [ inputs.zapret-discord-youtube.nixosModules.zapret-discord-youtube ];

  options.galaxy.services.zapret = {
    enable = lib.mkEnableOption "zapret-discord-youtube";
    testTools = lib.mkEnableOption "the zapret test tools" // {
      default = true;
    };
  };

  config = lib.mkIf cfg.enable {
    services.zapret-discord-youtube = {
      enable = true;
      configName = "general(ALT)";
      testTools.enable = cfg.testTools;
    };
  };
}
