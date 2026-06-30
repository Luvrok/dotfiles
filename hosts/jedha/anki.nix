{ username, config, ... }:

{
  sops.secrets.anki-pwd = { };
  services.anki-sync-server = {
    enable = true;
    port = 8130;
    address = "::";

    users = [
      {
        username = username;
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
}
