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
  imports = [ ./xray.nix ];

  # the voice assistant (Luvrok/jarvis): its models in llama-swap's
  # config.yaml, its menu in quickshell (hyprland's default.nix checks it)
  services.jarvis = {
    enable = true;
    # the hub's lfs cdn and docker hub need xray's mixed inbound
    proxy = lib.mkIf config.services.xray.enable "http://127.0.0.1:10808";
    # the llms in llama-swap's config.yaml, picked in the menu. the web
    # search stays (the local searxng), the notes are off: jarvis only talks
    llms = {
      jarvis = "Gemma 4 12B";
      jarvis-qwen-9b = "Qwen3.5 9B";
      jarvis-qwen-4b = "Qwen3.5 4B";
    };
  };

  sops.defaultSopsFile = ../../secrets/barnard.yaml;
  sops.defaultSopsFormat = "yaml";
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
  sops.age.generateKey = true;

  dotfiles = {
    hyprland.enable = true;
    # the docs index for pi and opencode, vectors from llama-swap
    docs-mcp.enable = true;
    # the obsidian vault's index for pi, vectors from llama-swap
    notes-mcp.enable = true;
    # api keys of opencode's free tiers
    opencode-keys.enable = true;
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
