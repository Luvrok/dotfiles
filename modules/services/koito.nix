{ config, lib, ... }:

{
  options.galaxy.services.koito.enable =
    lib.mkEnableOption "koito (ListenBrainz-compatible scrobbler)";

  config = lib.mkIf config.galaxy.services.koito.enable {
    galaxy.expose.koito = {
      port = 4110;
      subdomain = "koito";
    };

    sops.secrets."koito/env" = {
      restartUnits = [ "koito.service" ];
    };

    services.koito = {
      enable = true;
      environment = {
        KOITO_BIND_ADDR = "127.0.0.1";
        KOITO_LISTEN_PORT = config.galaxy.expose.koito.port;
        KOITO_DEFAULT_USERNAME = "koito";
        KOITO_LOGIN_GATE = "false";
      };
      environmentFile = config.sops.secrets."koito/env".path;
    };
  };
}
