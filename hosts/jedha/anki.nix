{ username, ... }:

{
  services.anki-sync-server = {
    enable = true;
    port = 8130;
    address = "::";

    users = [
      {
        username = username;
        passwordFile = "/run/secrets/anki-${username}-password";
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
      mkdir -p /run/secrets

      cp ${../../secrets/anki-${username}-password} /run/secrets/anki-${username}-password
      chmod 400 /run/secrets/anki-${username}-password
      chown root:root /run/secrets/anki-${username}-password
    '';
  };
}
