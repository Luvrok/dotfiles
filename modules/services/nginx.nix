# Public entry on mos-eisley. :443 is split by SNI: known names go to nginx
# (TLS on 127.0.0.1:8443), everything else to xray on 127.0.0.1:10443.
# Each name proxies to a local port that xray tunnels to the host in `from`.
{
  config,
  lib,
  self,
  ...
}:

let
  cfg = config.galaxy.services.nginx;

  exposed = lib.filterAttrs (_: e: e.subdomain != null) (
    self.nixosConfigurations.${cfg.from}.config.galaxy.expose
  );
  proxies = lib.mapAttrs' (_: e: lib.nameValuePair "${e.subdomain}.${cfg.domain}" e.port) exposed;

  listen = [
    {
      addr = "127.0.0.1";
      port = 8443;
      ssl = true;
    }
    {
      addr = "0.0.0.0";
      port = 80;
      ssl = false;
    }
  ];

  mkHost = host: port: {
    enableACME = true;
    forceSSL = true;
    inherit listen;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
      extraConfig = ''
        client_max_body_size 0;
        proxy_read_timeout 3600s;
      '';
    };
  };

  webNames = [
    cfg.domain
    "www.${cfg.domain}"
  ]
  ++ lib.attrNames proxies;
in
{
  options.galaxy.services.nginx = {
    enable = lib.mkEnableOption "the SNI router and reverse proxy";

    domain = lib.mkOption {
      type = lib.types.str;
      default = "vxrnt.ru";
    };

    from = lib.mkOption {
      type = lib.types.str;
      default = "jedha";
      description = "Host whose galaxy.expose entries with a subdomain get a vhost.";
    };

    acmeEmail = lib.mkOption {
      type = lib.types.str;
      default = "an0ni442@yandex.ru";
    };
  };

  config = lib.mkIf cfg.enable {
    security.acme = {
      acceptTerms = true;
      defaults.email = cfg.acmeEmail;
    };

    services.nginx = {
      enable = true;
      recommendedProxySettings = true;
      recommendedTlsSettings = true;
      recommendedGzipSettings = true;

      streamConfig = ''
        map $ssl_preread_server_name $upstream {
        ${lib.concatMapStrings (n: "  ${n} web;\n") webNames}  default xray;
        }

        upstream web  { server 127.0.0.1:8443; }
        upstream xray { server 127.0.0.1:10443; }

        server {
          listen 0.0.0.0:443;
          listen [::]:443;
          ssl_preread on;
          proxy_pass $upstream;
        }
      '';

      virtualHosts = {
        ${cfg.domain} = {
          serverAliases = [ "www.${cfg.domain}" ];
          root = "/var/www/${cfg.domain}";
          enableACME = true;
          forceSSL = true;
          inherit listen;
        };
      }
      // lib.mapAttrs mkHost proxies;
    };
  };
}
