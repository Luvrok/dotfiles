{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.galaxy.programs.git.enable = lib.mkEnableOption "git with gh and git-crypt";

  config = lib.mkIf config.galaxy.programs.git.enable {
    home-manager.users.${config.galaxy.host.user} = {
      programs.git = {
        enable = true;
        package = pkgs.git;
        settings = {
          user.email = "pawel.2020.navtop@gmail.com";
          user.name = "Luvrok";
          init.defaultBranch = "master";
        };
      };

      home.packages = with pkgs; [
        gh
        git-crypt
      ];
    };
  };
}
