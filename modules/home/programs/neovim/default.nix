# the whole config is the ./nvim dir, lazy-lock.json included: a copy of it
# works on another machine. nothing here is generated from nix: the paths of
# the qml modules and hyprland's lua stubs are found from the binaries at
# startup (nvim/lua/lsp.lua). the one thing nix does is the lock's link
{ config, lib, ... }:

let
  lock = "${config.home.homeDirectory}/HOME/infra/dotfiles/modules/home/programs/neovim/nvim/lazy-lock.json";
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
  };

  programs.vim.enable = true;

  home.file.".config/nvim" = {
    # the lock is not a store file: see below
    source = lib.cleanSourceWith {
      src = ./nvim;
      filter = path: _: baseNameOf path != "lazy-lock.json";
    };
    recursive = true;
  };

  # lazy-lock.json is the repo's own file, linked out of the store: a store
  # link is read-only, :Lazy update could not write it, and it writes the
  # repo's copy, the one the next switch and a copy of the config use
  home.file.".config/nvim/lazy-lock.json".source = config.lib.file.mkOutOfStoreSymlink lock;
}
