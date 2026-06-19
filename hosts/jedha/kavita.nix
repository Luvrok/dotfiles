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
    tokenKeyFile = "/etc/secrets/kavita-token.key";
    settings = {
      Port = 4545;
      IpAddresses = "::";
    };
  };
}
