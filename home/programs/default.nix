{ lib, config, pkgs, ... }:

{
  imports = [
    ./firefox
    ./neovim
    ./zsh
    ./rofi
    ./yazi
    ./greenclip
    ./git.nix
    ./gpg.nix
    ./mpv.nix
    ./neofetch.nix
  ];

  programs = {
    kitty = (import ./kitty/kitty.nix { inherit pkgs; });
  };
}
