# the whole config is the ./nvim dir, lazy-lock.json included: a copy of it
# works on another machine. nothing here is generated from nix: the paths of
# the qml modules and hyprland's lua stubs are found from the binaries at
# startup (nvim/lua/lsp.lua)
{ ... }:

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
