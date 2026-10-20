{ config, ... }:

let
  services = {
    "navidrome.vxrnt.ru" = 4533;
    "kavita.vxrnt.ru" = 4545;
    "qbt.vxrnt.ru" = 8129;
    "anki.vxrnt.ru" = 8130;
    "koito.vxrnt.ru" = 4110;
    "betanin.vxrnt.ru" = 9393;
    "metube.vxrnt.ru" = 8081;
    "docs.vxrnt.ru" = 6280;
  };

  mkHost = host: port: {
    enableACME = true;
    forceSSL = true;
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
      {
        addr = "[::]";
        port = 80;
        ssl = false;
      }
    ];
    locations."/" = {
      proxyPass = "http://127.0.0.1:${toString port}";
      proxyWebsockets = true;
      extraConfig = ''
        client_max_body_size 0;
        proxy_read_timeout 3600s;
      '';
    };
  };
in
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "an0ni442@yandex.ru";
  };

  sops.secrets.metube_htpasswd.owner = "nginx";
  sops.secrets.docs_mcp_htpasswd.owner = "nginx";

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;

    appendHttpConfig = ''
      absolute_redirect off;
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    '';

    streamConfig = ''
      map $ssl_preread_server_name $upstream {
        vxrnt.ru               web;
        www.vxrnt.ru           web;
        navidrome.vxrnt.ru     web;
        kavita.vxrnt.ru        web;
        qbt.vxrnt.ru           web;
        anki.vxrnt.ru          web;
        koito.vxrnt.ru         web;
        lt.vxrnt.ru            web;
        betanin.vxrnt.ru       web;
        metube.vxrnt.ru        web;
        docs.vxrnt.ru          web;
        default                xray;
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
      "vxrnt.ru" = {
        serverAliases = [ "www.vxrnt.ru" ];
        root = "/var/www/vxrnt.ru";
        enableACME = true;
        forceSSL = true;
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
      };

      "lt.vxrnt.ru" =
        let
          base = mkHost "lt.vxrnt.ru" 5389;
        in
        base
        // {
          locations = base.locations // {
            "= /sync".proxyPass = "http://127.0.0.1:8291";
            "= /rules".proxyPass = "http://127.0.0.1:8291";
            "= /subtitle-translator".return = "301 /subtitle-translator/";
            "/subtitle-translator/" = {
              proxyPass = "http://127.0.0.1:5390";
              extraConfig = ''
                client_max_body_size 20m;
                proxy_read_timeout 3600s;
                proxy_send_timeout 3600s;
              '';
            };
          };
        };
    }
    // builtins.mapAttrs mkHost services
    // {
      "metube.vxrnt.ru" = mkHost "metube.vxrnt.ru" 8081 // {
        basicAuthFile = config.sops.secrets.metube_htpasswd.path;
      };

      "docs.vxrnt.ru" = mkHost "docs.vxrnt.ru" 6280 // {
        basicAuthFile = config.sops.secrets.docs_mcp_htpasswd.path;
        locations = {
          # only the mcp endpoint, everything else is closed
          "/".return = "404";
          "= /mcp" = {
            proxyPass = "http://127.0.0.1:6280";
            extraConfig = ''
              # mcp answers as an sse stream, don't buffer it
              proxy_buffering off;
              proxy_cache off;
              proxy_read_timeout 3600s;
              client_max_body_size 1m;
            '';
          };
        };
      };
    };
  };
}
