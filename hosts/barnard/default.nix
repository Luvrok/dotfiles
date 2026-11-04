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

  # the voice assistant (Luvrok/jarvis), off for now: the module is mkIf
  # enable, so nothing of it runs, no unit, no models. its quickshell menu
  # and bar icon are gone too: commit 7eb562d is the last one that has them
  # (the menu starts the daemon on r, the bar stops it when idle), and the
  # unit's wantedBy needs lib.mkForce [ ] again when it comes back. the
  # settings stay for then
  services.jarvis = {
    enable = false;
    # the hub's lfs cdn and docker hub need xray's mixed inbound
    proxy = lib.mkIf config.services.xray.enable "http://127.0.0.1:10808";
    # the llms in llama-swap's config.yaml, picked in the menu. the web
    # search stays (the local searxng), the notes are off: jarvis only talks
    llms = {
      jarvis = "Gemma 4 12B";
      jarvis-qwen-9b = "Qwen3.5 9B";
      jarvis-qwen-4b = "Qwen3.5 4B";
    };
    # nothing listens for a wake phrase
    wakeWord.enable = false;
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
    # wine for games, in its own prefix (wine-games, winetricks-games)
    wine-gaming.enable = true;
    # sober, vinegar and the tools of studio. flathub goes through xray.
    # off for now, the settings stay for when it's back
    roblox = {
      enable = false;
      proxy = lib.mkIf config.services.xray.enable "http://127.0.0.1:10808";
      # roblox-player and roblox-studio go through xray's mixed inbound
      netns.enable = config.services.xray.enable;
    };
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
