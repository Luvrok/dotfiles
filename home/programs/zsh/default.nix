{ config, lib, pkgs, inputs, ... }:

{
  programs.zsh = {
    enable = true;
    initContent = ''
        source "${inputs.zinit}/zinit.zsh"
      ''
      + builtins.readFile ./zshrc;
    # Prevents keyboard input before the zsh prompt is fully initialized (feels right)
    envExtra = ''
      [[ -o interactive && -t 0 ]] || return
      stty -echo -icanon time 0 min 0 2>/dev/null
    '';
  };

  home.file.p10k = {
    enable = true;
    target = "./.p10k.zsh";
    source = ./.p10k.zsh;
  };

  programs.fzf.enable = true;
}
