{ lib, pkgs, ... }:

let
  setAll = types: app: lib.genAttrs types (_: app);

  imageTypes = [
    "image/png"
    "image/jpeg"
    "image/gif"
    "image/webp"
    "image/bmp"
    "image/tiff"
    "image/svg+xml"
    "image/avif"
    "image/heif"
    "image/heic"
    "image/jxl"
  ];

  videoTypes = [
    "video/mp4"
    "video/x-matroska"
    "video/webm"
    "video/quicktime"
    "video/x-msvideo"
    "video/mpeg"
    "video/ogg"
    "video/x-flv"
    "video/x-ms-wmv"
    "video/3gpp"
    "video/mp2t"
  ];

  audioTypes = [
    "audio/mpeg"
    "audio/flac"
    "audio/x-flac"
    "audio/ogg"
    "audio/opus"
    "audio/wav"
    "audio/x-wav"
    "audio/aac"
    "audio/mp4"
    "audio/x-m4a"
    "audio/webm"
    "audio/x-matroska"
  ];

  textTypes = [
    "text/plain"
    "text/markdown"
    "text/x-log"
    "text/csv"
    "text/x-shellscript"
    "application/x-shellscript"
    "application/json"
    "application/toml"
    "application/x-yaml"
    "application/xml"
    "text/xml"
    "text/css"
    "text/javascript"
    "application/javascript"
    "text/x-nix"
    "text/x-go"
    "text/x-python"
    "text/x-csrc"
    "text/x-chdr"
    "text/x-c++src"
  ];

  browserTypes = [
    "text/html"
    "application/xhtml+xml"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
    "x-scheme-handler/about"
    "x-scheme-handler/unknown"
  ];

  # terminal apps wrapped in kitty, Terminal=true is flaky with xdg-open outside a de
  nvim-kitty = pkgs.makeDesktopItem {
    name = "nvim-kitty";
    desktopName = "nvim (kitty)";
    exec = "kitty -e nvim %F";
    noDisplay = true;
    mimeTypes = textTypes;
  };

  yazi-kitty = pkgs.makeDesktopItem {
    name = "yazi-kitty";
    desktopName = "yazi (kitty)";
    exec = "kitty -e yazi %f";
    noDisplay = true;
    mimeTypes = [ "inode/directory" ];
  };
in
{
  environment.systemPackages = [
    nvim-kitty
    yazi-kitty
    pkgs.xdg-user-dirs
  ];

  xdg = {
    mime = {
      enable = true;
      defaultApplications =
        setAll imageTypes "nsxiv.desktop"
        // setAll videoTypes "mpv.desktop"
        // setAll audioTypes "mpv.desktop"
        // setAll textTypes "nvim-kitty.desktop"
        // setAll browserTypes "librewolf.desktop"
        // {
          # check the real name, newer zathura ships org.pwmt.zathura.desktop
          "application/pdf" = "org.pwmt.zathura.desktop";
          # or "yazi-kitty.desktop"
          "inode/directory" = "thunar.desktop";
        };
    };

    portal = {
      enable = true;
      wlr = {
        enable = true;
        settings.screencast = {
          chooser_type = "simple";
          chooser_cmd = "${pkgs.slurp}/bin/slurp -f %o -or";
        };
      };
      extraPortals = [
        pkgs.xdg-desktop-portal-gtk
        pkgs.xdg-desktop-portal-termfilechooser
      ];
      config.common = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
      };
      config.sway = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.ScreenCast" = [ "wlr" ];
        "org.freedesktop.impl.portal.Screenshot" = [ "wlr" ];
      };
      config.hyprland = {
        default = [
          "hyprland"
          "gtk"
        ];
        "org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];
      };
    };
  };

  # termfilechooser falls back to /etc/xdg when ~/.config has no config
  environment.etc."xdg/xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=${pkgs.xdg-desktop-portal-termfilechooser}/share/xdg-desktop-portal-termfilechooser/yazi-wrapper.sh
    env=TERMCMD=kitty --class filechooser
  '';

  # read by xdg-user-dirs-update, paths are relative to home
  environment.etc."xdg/user-dirs.defaults".text = ''
    DESKTOP=desktop
    DOWNLOAD=downloads
    DOCUMENTS=documents
    MUSIC=documents/music
    PICTURES=documents/pictures
    VIDEOS=documents/videos
    PUBLICSHARE=documents/public
    TEMPLATES=documents/templates
  '';

  # relink on every login, so app writes don't stick
  systemd.user.tmpfiles.rules = [
    "L+ %h/.config/mimeapps.list - - - - /etc/xdg/mimeapps.list"
  ];

  # gtk3 apps use the portal file picker
  environment.sessionVariables.GTK_USE_PORTAL = "1";
}
