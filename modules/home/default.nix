{
  pkgs,
  username,
  ...
}:

{
  programs.home-manager.enable = true;

  imports = [
    ./packages.nix
    ./services
    ./programs
  ];

  home.stateVersion = "26.05";
  home.username = "${username}";
  home.homeDirectory = "/home/${username}";

  home.file.".local/share/v2rayN/bin/xray/xray".source = "${pkgs.xray}/bin/xray";
  home.file.".local/share/v2rayN/bin/sing_box/sing-box".source = "${pkgs.sing-box}/bin/sing-box";

  home.file.".Xresources" = {
    executable = true;
    text = ''
      Xcursor.theme: Vanilla-DMZ
      Xcursor.size: 32

      Nsxiv.window.background: #1d2021
      Nsxiv.window.foreground: #ebdbb2
      Nsxiv.bar.background: #1d2021
      Nsxiv.bar.foreground: #ebdbb2
      Nsxiv.mark.foreground: #d65d0e
      Nsxiv.bar.font: JetBrainsMonoNL Nerd Font:size=14
    '';
  };

  home.pointerCursor = {
    enable = true;
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 32;
  };

  home.file.".local/bin" = {
    source = ./local/sh;
    recursive = true;
    executable = true;
  };

  home.file.".local/media" = {
    source = ./local/media;
    recursive = true;
    executable = true;
  };

  home.file.".config/.asoundrc".source = ./local/asoundrc;

  # the terminal file chooser portal: it only looks in $XDG_CONFIG_HOME, not
  # /etc/xdg, so the config has to be a user file (it says "no config file
  # found, using the default" otherwise). One picker runs at a time and the
  # backend waits for it, so a picker that never closes blocks every file
  # dialog in every app.
  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=${pkgs.xdg-desktop-portal-termfilechooser}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
    env=TERMCMD=kitty --title termfilechooser --class filechooser
  '';
}
