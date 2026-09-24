{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.galaxy.programs.zsh.enable = lib.mkEnableOption "zsh with p10k and fzf-tab";

  config = lib.mkIf config.galaxy.programs.zsh.enable {
    galaxy.files.home = {
      ".config/zsh/zshrc" = ./config/zshrc;
      ".p10k.zsh" = ./config/p10k.zsh;
    };

    home-manager.users.${config.galaxy.host.user} =
      { config, ... }:
      {
        programs.zsh = {
          enable = true;

          autosuggestion.enable = true;
          syntaxHighlighting.enable = true;
          enableCompletion = true;

          plugins = [
            {
              name = "powerlevel10k";
              src = pkgs.zsh-powerlevel10k;
              file = "share/zsh-powerlevel10k/powerlevel10k.zsh-theme";
            }
            {
              name = "fzf-tab";
              src = pkgs.fetchFromGitHub {
                owner = "Aloxaf";
                repo = "fzf-tab";
                rev = "master";
                sha256 = "sha256-YhTSu0P7mFlVx1zBvbT0jNstkamcZHhPYJHKMAHgyuM=";
              };
              file = "fzf-tab.plugin.zsh";
            }
          ];

          # Sourced instead of inlined, so it can be linked from the repo (galaxy.files.mutable).
          initContent = ''
            source ${config.xdg.configHome}/zsh/zshrc
          '';
        };

        programs.fzf = {
          enable = true;
          enableZshIntegration = true;
        };
      };
  };
}
