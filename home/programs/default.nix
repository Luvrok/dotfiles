{ pkgs, ... }:

{
  imports = [
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
  ];

  programs = {
    kitty = (import ./kitty/kitty.nix { inherit pkgs; });
  };
}
