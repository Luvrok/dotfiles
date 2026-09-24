{ config, lib, ... }:

{
  options.galaxy.services.anki.enable = lib.mkEnableOption "anki sync server";

  config = lib.mkIf config.galaxy.services.anki.enable {
    galaxy.expose.anki = {
      port = 8130;
      subdomain = "anki";
    };

    sops.secrets.anki-pwd = { };
    services.anki-sync-server = {
      enable = true;
      port = config.galaxy.expose.anki.port;
      address = "::";

      users = [
        {
          username = config.galaxy.host.user;
          passwordFile = config.sops.secrets.anki-pwd.path;
        }
      ];
    };

    systemd.services.anki-secrets = {
      description = "Install Anki passwords from git-crypt";
      wantedBy = [ "multi-user.target" ];
      before = [ "anki-sync-server.service" ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        chmod 400 /run/secrets/anki-pwd
        chown root:root /run/secrets/anki-pwd
      '';
    };
  };
}
