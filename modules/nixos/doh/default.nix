{ ... }:

{
  services.dnscrypt-proxy = {
    enable = true;
    settings = {
      listen_addresses = [ "127.0.0.1:5053" ];

      doh_servers = true;
      dnscrypt_servers = false;
      ipv6_servers = false;

      require_dnssec = true; # only resolvers with DNSSEC

      # Several providers: queries go to the fastest working ones, a blocked one is skipped
      server_names = [
        "quad9-doh-ip4-port443-nofilter-pri"
        "cloudflare"
        "adguard-dns-unfiltered-doh"
      ];
      # Google isn't marked as no-log and would be filtered out otherwise
      require_nolog = false;

      # Give up on a slow server sooner and ask another one (default 5000)
      timeout = 2500;

      # Top-level keys replace the upstream defaults, so the whole block is here.
      # cache_file must be writable, the config itself is in the read-only store.
      sources.public-resolvers = {
        urls = [
          "https://raw.githubusercontent.com/DNSCrypt/dnscrypt-resolvers/master/v3/public-resolvers.md"
          "https://download.dnscrypt.info/resolvers-list/v3/public-resolvers.md"
          "https://cdn.jsdelivr.net/gh/DNSCrypt/dnscrypt-resolvers@master/v3/public-resolvers.md"
        ];
        cache_file = "/var/lib/dnscrypt-proxy/public-resolvers.md";
        minisign_key = "RWQf6LRCGA9i53mlYecO4IzT51TGPpvWucNSCh1CBM0QTaLn73Y7GFO3";
        refresh_delay = 73;
      };
    };
  };

  services.resolved = {
    enable = true;
    settings.Resolve = {
      DNS = [ "127.0.0.1:5053" ];
      # Plain DNS only over loopback, dnscrypt-proxy encrypts the rest
      DNSOverTLS = false;
      # Route every name to dnscrypt-proxy, never to per-link servers
      Domains = [ "~." ];
      DNSSEC = false;
      LLMNR = false;
      # Disable the compiled-in plaintext fallback servers
      FallbackDNS = [ ];
      # If dnscrypt-proxy is down, answer from expired cache instead of failing
      StaleRetentionSec = "1d";
    };
  };
}
