# mpv with the Luvrok/mpv-config fork; config/ overrides mpv.conf and input.conf.
{
  config,
  lib,
  pkgs,
  ...
}:

let
  mpv-config = pkgs.stdenvNoCC.mkDerivation {
    pname = "mpv-config";
    version = "fork-pinned-11.09.2025";
    src = pkgs.fetchFromGitHub {
      owner = "Luvrok";
      repo = "mpv-config";
      rev = "c2a8fed053b01b81df02b2679dbadcf75a7822d4";
      hash = "sha256-jmeOUKAs3gcEuiXqo6FclTGOMrWMcEQdGZlXFpdJjHs=";
    };
    installPhase = ''
      set -euo pipefail

      mkdir -p "$out"
      cp -r "$src/portable_config/"* "$out/"

      rm -f "$out/mpv.conf"
      install -Dm644 ${./config/mpv.conf} "$out/mpv.conf"

      rm -f "$out/inputs.conf"
      install -Dm644 ${./config/input.conf} "$out/input.conf"

      substituteInPlace "$out/script-opts/memo.conf" \
        --replace '~~/script-opts/memo-history.log' '~/.local/state/mpv/memo-history.log'
    '';
  };
in
{
  options.galaxy.programs.mpv.enable = lib.mkEnableOption "mpv";

  config = lib.mkIf config.galaxy.programs.mpv.enable {
    home-manager.users.${config.galaxy.host.user} = {
      programs.mpv.enable = true;
      xdg.configFile."mpv".source = mpv-config;
    };
  };
}
