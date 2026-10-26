{ config, pkgs, ... }: 

{
  sops.secrets.searxng-env = { };

  services.searx = {
    enable = true;
    package = pkgs.searxng;

    environmentFile = config.sops.secrets.searxng-env.path;

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
