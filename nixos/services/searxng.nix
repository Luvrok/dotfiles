{ config, pkgs, ... }: {
  # File content (one line):  SEARXNG_SECRET=<output of `openssl rand -hex 32`>
  sops.secrets.searxng-env = { };

  services.searx = {
    enable = true;
    package = pkgs.searxng;

    # SearXNG reads SEARXNG_SECRET from the environment and uses it as
    # server.secret_key, so the secret never lands in the Nix store.
    environmentFile = config.sops.secrets.searxng-env.path;

    settings = {
      server = {
        bind_address = "127.0.0.1"; # local only, pi and the browser on barnard
        port = 11433;
        # Rate limiter needs Redis/Valkey; pointless for a single local user
        limiter = false;
        public_instance = false;
      };

      # pi-web-access talks to the JSON API; html keeps the web UI working
      search.formats = [ "html" "json" ];

      ui.default_locale = "en";
    };
  };
}
