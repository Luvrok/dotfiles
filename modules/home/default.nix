{
  pkgs,
  username,
  fontSize,
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

  home.file.".config/rofi" = {
    source = ./programs/rofi/config;
    recursive = true;
  };

  home.file.".config/rofi/font.rasi".source =
    if fontSize < 14 then
      ./programs/rofi/font/font-dpi-low.rasi
    else
      ./programs/rofi/font/font-dpi-high.rasi;

  home.file.".config/.asoundrc".text = ''
    defaults.pcm.card 1
    defaults.ctl.card 1
  '';
}
