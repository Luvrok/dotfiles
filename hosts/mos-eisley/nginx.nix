{ ... }:

let
  services = {
    "navidrome.vxrnt.ru" = 4533;
    "kavita.vxrnt.ru"    = 4545;
    "qbt.vxrnt.ru"       = 8129;
    "anki.vxrnt.ru"      = 8130;
  };

  mkHost = host: port: {
    enableACME = true;
    forceSSL = true;
    listen = [
      { addr = "127.0.0.1"; port = 8443; ssl = true; }
      { addr = "0.0.0.0";   port = 80;   ssl = false; }
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

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;

    streamConfig = ''
      map $ssl_preread_server_name $upstream {
        vxrnt.ru               web;
        www.vxrnt.ru           web;
        navidrome.vxrnt.ru     web;
        kavita.vxrnt.ru        web;
        qbt.vxrnt.ru           web;
        anki.vxrnt.ru          web;
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
          { addr = "127.0.0.1"; port = 8443; ssl = true; }
          { addr = "0.0.0.0";   port = 80;   ssl = false; }
        ];
      };
    } // builtins.mapAttrs mkHost services;
  };
}
