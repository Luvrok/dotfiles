{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    # based
    direnv
    kitty
    fish
    neofetch
    p7zip
    tree-sitter
    dunst
    rnnoise-plugin
    helvum
    ly
    zathura

    # pass
    pass
    pinentry-curses
    pwgen
    pass-secret-service
    libsecret

    # utils
    haskellPackages.greenclip

    poppler-utils
    dragon-drop
  ];
}
