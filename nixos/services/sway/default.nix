# sway: the wayland twin of the i3 session, same tags, binds and bar, no
# animations. sddm lists it next to i3 (its greeter stays on x11, it starts
# wayland sessions all the same). i3 stays the default session
{ pkgs, ... }:

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
      # wayland where the app can, xwayland for the rest. gpu works in both,
      # but xwayland apps get blurry on a scaled output (dash)

      # chromium and the electron apps from nixpkgs: discord, obsidian, element...
      export NIXOS_OZONE_WL=1
      # qt5 apps without the wayland plugin fall back to x11
      export QT_QPA_PLATFORM="wayland;xcb"
      # sway scales qt by itself, the x11 factor from hosts/alderaan/env.nix doubles it
      unset QT_SCREEN_SCALE_FACTORS
      # rofi-pass copies with wl-copy, xclip reaches xwayland apps only
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

  # the sway module turns it on, then i3 starts xdg autostart files too
  # (blueman-applet and such). i3 never ran them, sway doesn't either
  services.xserver.desktopManager.runXdgAutostartIfNone = false;
}
