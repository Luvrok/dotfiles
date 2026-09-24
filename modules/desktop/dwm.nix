{
  config,
  lib,
  pkgs,
  ...
}:

let
  c = config.galaxy.theme.colors;
  inherit (config.galaxy.theme) font;
in
{
  options.galaxy.desktop.dwm.enable = lib.mkEnableOption "dwm (package from pkgs/dwm)";

  config = lib.mkIf config.galaxy.desktop.dwm.enable {
    services.xserver.windowManager.dwm = {
      enable = true;
      package = pkgs.dwm;
    };

    services.displayManager.defaultSession = "none+dwm";

    # Read by dwm, st and dmenu (xrdb patches).
    home-manager.users.${config.galaxy.host.user}.home.file.".Xresources" = {
      executable = true;
      text = ''
        ! normal
        st.normbgcolor:      #000000
        st.normbordercolor:  ${c.bg1}
        st.normfgcolor:      ${c.fg}

        ! selected
        st.selfgcolor:       ${c.fg0}
        st.selbordercolor:   ${c.orange}
        st.selbgcolor:       #000000

        dwm.normbordercolor: ${c.bg1}
        dwm.normbgcolor: ${c.bg}
        dwm.normfgcolor: ${c.fg}
        dwm.selbordercolor: ${c.orange}
        dwm.selbgcolor: ${c.orange}
        dwm.selfgcolor: ${c.fg0}

        font: ${font}:size=11

        ! normal
        normfgcolor:        ${c.fg}
        normbgcolor:        ${c.bg}

        ! selected
        selfgcolor:         ${c.fg0}
        selbgcolor:         ${c.orange}

        ! out
        outfgcolor:         ${c.fg}
        outbgcolor:         ${c.bg}

        ! border
        selbordercolor:     ${c.orange}

        Xcursor.theme: Vanilla-DMZ
        Xcursor.size: 32
      '';
    };
  };
}
