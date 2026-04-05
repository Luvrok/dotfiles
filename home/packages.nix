{ config, pkgs, lib, ... }:

{
  home.packages = with pkgs; [
    # based
    direnv
    kitty
    fish
    fastfetch
    p7zip
    tree-sitter
    rnnoise-plugin
    ly
    nsxiv
    figlet

    # pass
    pass
    pinentry-curses
    pwgen
    pass-secret-service
    libsecret

    poppler-utils
    dragon-drop
  ];
}
