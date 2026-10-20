# sway: the wayland twin of the i3 session, same tags, binds and bar, no
# animations (swayfx has them, but its effect buffers take ~150 mb of vram
# on two 1440p monitors). sddm lists it next to i3 (its greeter stays on x11, it starts wayland
# sessions all the same). i3 stays the default session. barnard only, its
# env.nix imports this
{ lib, pkgs, ... }:

let
  # jq filters use $vars inside single quotes on purpose (SC2016)
  script =
    name: runtimeInputs:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      excludeShellChecks = [ "SC2016" ];
      text = builtins.readFile ./scripts/${name};
    };
in
{
  programs.sway = {
    enable = true;

    # no tab bars, like the i3 patch in nixos/overlays: the bar has the titles.
    # 0 is what hide_lone_tab uses for a lone tab, here it's every tab
    package = pkgs.sway.override {
      sway-unwrapped = pkgs.sway-unwrapped.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace sway/tree/container.c \
            --replace-fail 'return config->font_height + config->titlebar_v_padding * 2;' 'return 0;'
        '';
      });
    };

    # runs before sway starts, everything in the session gets it
    extraSessionCommands = ''
      # wayland where the app can, xwayland for the rest, gpu works in both

      # chromium and the electron apps from nixpkgs: discord, obsidian, element...
      export NIXOS_OZONE_WL=1
      # qt5 apps without the wayland plugin fall back to x11
      export QT_QPA_PLATFORM="wayland;xcb"
      # rofi-pass copies with wl-copy (rofi-pass.nix reads it)
      export ROFI_PASS_CLIPBOARD_BACKEND=wl-clipboard
    '';

    # wayland stand-ins for what i3 uses, started from sway config
    extraPackages = with pkgs; [
      swayidle # xidlehook
      sway-audio-idle-inhibit # xidlehook --not-when-audio
      gammastep # redshift
      wl-clipboard # xclip
      cliphist # greenclip
      grim # flameshot
      slurp
    ];
  };

  # the module puts the default config there, this one wins
  environment.etc."sway/config".source = ./config;
  # bar config, eww-sway-launch runs its own daemon on it
  environment.etc."sway/eww".source = ./eww;

  # swaymsg comes with sway above, rofi and tesseract from PATH like in
  # rofi-greenclip and ocr
  environment.systemPackages = with pkgs; [
    (script "sway-ws" [ jq coreutils ])
    (script "sway-tile" [ jq coreutils ])
    (script "sway-sp" [ jq util-linux ])
    (script "sway-clip" [ cliphist wl-clipboard ])
    (script "sway-shot" [ grim slurp wl-clipboard libnotify ])
    (script "sway-xkb" [ jq coreutils ])
    (script "eww-sway-launch" [ eww jq coreutils ])
    (script "eww-sway-workspaces" [ jq ])
    (script "eww-sway-windows" [ jq ])
  ];

  # the module sets the sway portals: gtk, wlr for screen sharing and
  # screenshots. the file picker stays yazi like in i3 (xdg module)
  xdg.portal.config.sway."org.freedesktop.impl.portal.FileChooser" = [ "termfilechooser" ];

  # gtk on wayland takes theme, icons, font and cursor from dconf through the
  # settings portal and skips settings.ini, so the same as
  # nixos/modules/gtk/settings.ini goes here. x11 gtk doesn't read these
  programs.dconf.profiles.user.databases = [
    {
      settings."org/gnome/desktop/interface" = {
        gtk-theme = "gruvbox-flat";
        icon-theme = "Gruvbox-Plus-Dark";
        font-name = "JetBrainsMonoNL Nerd Font Propo 10";
        # home.pointerCursor, x11 gets it from there
        cursor-theme = "Vanilla-DMZ";
        cursor-size = lib.gvariant.mkInt32 32;
      };
    }
  ];

  # the sway module turns it on, then i3 starts xdg autostart files too
  # (blueman-applet and such). i3 never ran them, sway doesn't either
  services.xserver.desktopManager.runXdgAutostartIfNone = false;
}
