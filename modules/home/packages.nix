{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # based
    direnv
    kitty
    fish
    fastfetch
    p7zip
    ly
    figlet

    # pass
    pass
    pinentry-curses
    pwgen
    pass-secret-service
    libsecret

    poppler-utils
    dragon-drop
    # youtube (and other sites) in mpv, the mpv-pip extension too
    yt-dlp
  ];
}
