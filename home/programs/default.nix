{ lib, config, pkgs, ... }:

{
  imports = [
    ./firefox
    ./neovim
    ./zsh
    ./rofi
    ./yazi
    ./git.nix
    ./xresources.nix
    ./gpg.nix
    ./mpv.nix
    ./neofetch.nix
  ];

  programs = {
    kitty = (import ./kitty/kitty.nix { inherit pkgs; });
  };
}
