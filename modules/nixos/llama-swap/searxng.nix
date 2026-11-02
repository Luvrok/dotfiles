{ pkgs, ... }:

let
  # SEARXNG_SECRET, made once on the host. it signs cookies and image proxy
  # urls of an instance only 127.0.0.1 sees, nothing to keep in sops
  secretFile = "/var/lib/searxng-secret/env";
in
{
  systemd.services.searxng-secret = {
    description = "Make the searxng secret key";
    before = [ "searx-init.service" ];
    requiredBy = [ "searx-init.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      StateDirectory = "searxng-secret";
      StateDirectoryMode = "0700";
      UMask = "0077";
    };
    script = ''
      [ -s ${secretFile} ] ||
        echo "SEARXNG_SECRET=$(${pkgs.openssl}/bin/openssl rand -hex 32)" > ${secretFile}
    '';
  };

  services.searx = {
    enable = true;
    package = pkgs.searxng;

    environmentFile = secretFile;

    settings = {
      server = {
        bind_address = "127.0.0.1";
        port = 11433;
        limiter = false;
        public_instance = false;
      };

      # engines see the vpn's ip and the proxy resolves hostnames, a dead proxy fails the search
      outgoing = {
        proxies."all://" = [ "http://127.0.0.1:10808" ];
        # the default 3 s request_timeout leaves too little for the extra hop
        extra_proxy_timeout = 5;
      };

      search.formats = [ "html" "json" ];
      ui.default_locale = "en";
    };
  };
}
