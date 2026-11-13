{ config, ... }:

let
  inherit (import ./camouflage-domain.nix) domain;

  # the vhost itself is in sops, because its server_name is the sni and
  # this file is public. nginx reads it as root, on start and on reload
  site = config.sops.secrets.nginx_conf.path;
in
{
  services.nginx = {
    enable = true;
    recommendedTlsSettings = true;
    recommendedGzipSettings = true;
    recommendedOptimisation = true;
    serverTokens = false;

    appendHttpConfig = ''
      include ${site};
    '';
  };

  # the site is the reality target, so it has to look like an ordinary host:
  # a trusted certificate, h2 and a real page. http-01 needs only port 80,
  # which the vhost answers under /.well-known/acme-challenge/
  security.acme = {
    acceptTerms = true;
    # letsencrypt only uses this for expiry mail, but it does link this
    # domain to the others issued with the same account: replace it if that
    # matters
    defaults.email = "an0ni442@yandex.ru";

    certs.camouflage = {
      inherit domain;
      group = "nginx";
      webroot = "/var/lib/acme/acme-challenge";
      reloadServices = [ "nginx.service" ];
    };
  };

  sops.secrets.nginx_conf = {
    mode = "0400";
    restartUnits = [ "nginx.service" ];
  };

  # the page carries no secrets, only the domain does, so a generic landing
  # that can be moved to another name unchanged
  systemd.tmpfiles.rules = [
    "C+ /var/www/camouflage/index.html 0644 root root - ${./www/index.html}"
    "C+ /var/www/camouflage/robots.txt 0644 root root - ${./www/robots.txt}"
  ];

  # nginx cannot read its config before the secret is in place, and the
  # self-signed pair from acme has to exist before the first start
  systemd.services.nginx = {
    wants = [
      "acme-camouflage.service"
      "sops-install-secrets.service"
    ];
    after = [
      "acme-camouflage.service"
      "sops-install-secrets.service"
    ];
    # the renewal uses the webroot below, so nginx has to be up first
    before = [ "acme-order-renew-camouflage.service" ];
  };
}
