{ config, lib, ... }:

{
  options.galaxy.programs.neovim.enable = lib.mkEnableOption "neovim with the config from ./config";

  config = lib.mkIf config.galaxy.programs.neovim.enable {
    galaxy.files.home = config.galaxy.lib.linkTree ".config/nvim" ./config;

    home-manager.users.${config.galaxy.host.user} = {
      programs = {
        neovim = {
          enable = true;
          defaultEditor = true;
        };

        vim.enable = true;
      };

      # home-manager writes its own init.lua (provider switches only); ours wins.
      xdg.configFile."nvim/init.lua".enable = lib.mkForce false;
    };
  };
}
