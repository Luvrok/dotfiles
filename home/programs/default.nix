{ lib, config, pkgs, ... }:

{
  imports = [
    ./firefox
    ./librewolf
    ./neovim
    ./zsh
    ./rofi
    ./yazi
    ./greenclip
    ./git.nix
    ./gpg.nix
    ./mpv.nix
    ./zathura.nix
    ./neofetch.nix
  ];

  programs = {
    kitty = (import ./kitty/kitty.nix { inherit pkgs; });
  };
}
