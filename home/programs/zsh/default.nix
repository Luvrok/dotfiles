{ pkgs, ... }:

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
          sha256 = "sha256-yvPQyuK4Dw+LkwxrkWTRcw4PIf/79fW61jWbEg8Pe9Y=";
        };
        file = "fzf-tab.plugin.zsh";
      }
    ];

    initContent = builtins.readFile ./zshrc;
  };

  home.file.".p10k.zsh".source = ./p10k.zsh;

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };
}
