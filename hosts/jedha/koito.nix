{ config, ... }:

{
  sops.secrets."koito/env" = {
    restartUnits = [ "koito.service" ];
  };

  services.koito = {
    enable = true;
    environment = {
      KOITO_BIND_ADDR = "127.0.0.1";
      KOITO_LISTEN_PORT = 4110;
      KOITO_DEFAULT_USERNAME = "koito";
      KOITO_LOGIN_GATE = "false";
    };
    environmentFile = config.sops.secrets."koito/env".path;
  };
}
