{ lib, ... }:

let
  # one Let's Encrypt certificate per host. the vhosts themselves are in
  # nginx/http.conf, so this list has to stay in sync with it
  domains = [
    "anki.vxrnt.ru"
    "betanin.vxrnt.ru"
    "kavita.vxrnt.ru"
    "koito.vxrnt.ru"
    "lt.vxrnt.ru"
    "metube.vxrnt.ru"
    "navidrome.vxrnt.ru"
    "obsidian.vxrnt.ru"
    "qbt.vxrnt.ru"
    "rss.vxrnt.ru"
    "vxrnt.ru"
  ];

  certServices = map (domain: "acme-${domain}.service") domains;
in
{
  security.acme = {
    acceptTerms = true;
    defaults.email = "an0ni442@yandex.ru";

    certs = lib.genAttrs domains (domain: {
      group = "nginx";
      reloadServices = [ "nginx.service" ];
      # the same public directory the vhosts in http.conf answer challenges from
      webroot = "/var/lib/acme/acme-challenge";
      extraDomainNames = lib.optional (domain == "vxrnt.ru") "www.vxrnt.ru";
    });
  };

  # TODO: sops. once mos-eisley has an age key, read this from
  # sops.secrets.metube_htpasswd instead of /var/lib/metube-htpasswd

  system.activationScripts.vxrntSite = ''
    mkdir -p /var/www/vxrnt.ru
    cp -f ${./www}/index.html /var/www/vxrnt.ru/index.html
    chmod 0644 /var/www/vxrnt.ru/index.html
  '';

  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;

    appendHttpConfig = ''
      absolute_redirect off;
      add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

      include ${./nginx/http.conf};
    '';

    streamConfig = ''
      include ${./nginx/stream.conf};
    '';
  };

  # with the vhosts in a plain file the module cannot see them, so nginx has
  # to be ordered after the certificate services by hand
  systemd.services.nginx = {
    wants = certServices;
    after = certServices;
    before = map (domain: "acme-order-renew-${domain}.service") domains;
  };
}
