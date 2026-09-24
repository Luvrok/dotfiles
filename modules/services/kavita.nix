{ config, lib, ... }:

{
  options.galaxy.services.kavita.enable = lib.mkEnableOption "kavita";

  config = lib.mkIf config.galaxy.services.kavita.enable {
    galaxy.expose.kavita = {
      port = 4545;
      subdomain = "kavita";
    };

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
        Port = config.galaxy.expose.kavita.port;
        IpAddresses = "::";
      };
    };
  };
}
