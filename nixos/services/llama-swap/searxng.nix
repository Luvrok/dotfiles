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

      search.formats = [ "html" "json" ];
      ui.default_locale = "en";
    };
  };
}
