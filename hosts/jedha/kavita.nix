{ lib, ... }:

{
  users.users.kavita = {
    isSystemUser = true;
    extraGroups = [ "media" ];
  };

  systemd.services.kavita = {
    serviceConfig = {
      UMask = lib.mkForce "0002";
    };
  };

  services.kavita = {
    enable = true;
    user = "kavita";
    dataDir = "/var/lib/kavita";
    # openssl rand -base64 64 | tr -d '\n' > /etc/secrets/kavita-token.key
    # settings.TokenKey is "@token_key@", the module puts the file's
    # content there. the old tokenKeyFile is renamed to settings.TokenKey,
    # so it gave kavita the path itself as the key (232 bits, too short)
    credentials.token_key = "/etc/secrets/kavita-token.key";
    settings = {
      Port = 4545;
      IpAddresses = "127.0.0.1";
    };
  };
}
