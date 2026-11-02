{
  config,
  lib,
  pkgs,
  inputs,
  username,
  ...
}:

let
  # the logins of the downloads, sops secrets/arr.yaml, then git add
  arrSecrets = ../../secrets/arr.yaml;
  hasArrSecrets = builtins.pathExists arrSecrets;
in
{
  imports = [
    ./xray.nix
    # docs index for pi, vectors from llama-swap
    ../../modules/nixos/docs-mcp
    # the obsidian vault, its own index next to it
    ../../modules/nixos/notes-mcp
    # the wayland sessions
    ../../modules/nixos/sway
    ../../modules/nixos/hyprland
    # kodi, the movies and series of /media/outer-1 played in mpv, and
    # their downloads: radarr, sonarr, qbittorrent, subtitles (Luvrok/kodi)
    inputs.kodi.nixosModules.default
    # api keys of opencode's free tiers
    ../../modules/nixos/opencode-keys.nix
  ];

  # the voice assistant (Luvrok/jarvis): its models in llama-swap's
  # config.yaml, its menu in quickshell (hyprland's default.nix checks it)
  services.jarvis = {
    enable = true;
    # the hub's lfs cdn and docker hub need xray's mixed inbound
    proxy = lib.mkIf config.services.xray.enable "http://127.0.0.1:10808";
    # the notes' own docs-mcp-server (modules/nixos/notes-mcp)
    tools.notesMcp = "http://127.0.0.1:6281/mcp";
  };

  # the gpu driver and the font size of the desktop (modules/nixos/desktop)
  videoDrivers = [ "amdgpu" ];
  fontSize = 11;

  services.kodi = {
    enable = true;
    user = username;
    # radarr, sonarr, prowlarr and bazarr: their servers are behind
    # cloudflare, the provider stalls it
    proxy = lib.mkIf config.services.xray.enable "http://127.0.0.1:10808";
    arr.secrets = lib.mkIf hasArrSecrets config.sops.secrets.arr.path;
    # jedha's subtitle-translator through jedha-tunnel.nix, then the same
    # from outside
    arr.translators = [
      "http://127.0.0.1:5390/subtitle-translator"
      "https://lt.vxrnt.ru/subtitle-translator"
    ];
  };
  warnings = lib.optional (
    !hasArrSecrets
  ) "secrets/arr.yaml is missing (or not git added): no rutracker, opensubtitles.com or translations";
  # the whole file, a key that isn't there is just not used
  sops.secrets.arr = lib.mkIf hasArrSecrets {
    sopsFile = arrSecrets;
    format = "yaml";
    key = "";
    owner = username;
    restartUnits = [ "arr-setup.service" ];
  };

  # the sddm greeter runs in weston, on the first output: DP-1, the main one
  # on the right. us,ru like the sessions, the theme's color under it.
  # kiosk is the shell the sddm module uses
  services.displayManager.sddm.wayland.compositorCommand =
    let
      ini = (pkgs.formats.ini { }).generate "weston.ini" {
        shell.background-color = "0xff171717";
        keyboard = {
          keymap_layout = "us,ru";
          keymap_options = "grp:win_space_toggle";
        };
      };
    in
    "${lib.getExe pkgs.weston} --shell=kiosk -c ${ini}";

  environment.sessionVariables = {
    XFT_DPI = "109";
    XCURSOR_THEME = "Vanilla-DMZ";
    XCURSOR_SIZE = "32";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  environment.extraInit = ''
    #Turn off gui for ssh auth
    unset -v SSH_ASKPASS
  '';
}
