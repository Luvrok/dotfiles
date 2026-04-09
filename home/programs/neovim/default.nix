{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  programs.vim.enable = true;

  home.file.".config/nvim" = {
    source = ./nvim;
    recursive = true;
  };
}
