# home-manager for the main user. Other modules add to home-manager.users.<user>.
{
  config,
  lib,
  inputs,
  ...
}:

let
  inherit (config.galaxy.host) user;
in
{
  options.galaxy.home.enable = lib.mkEnableOption "home-manager for the main user";

  config = lib.mkIf config.galaxy.home.enable {
    home-manager = {
      useGlobalPkgs = true;
      useUserPackages = true;
      backupFileExtension = "backup";
      extraSpecialArgs = { inherit inputs; };

      users.${user} = {
        programs.home-manager.enable = true;

        home = {
          stateVersion = "26.05";
          username = user;
          homeDirectory = "/home/${user}";
        };
      };
    };
  };
}
