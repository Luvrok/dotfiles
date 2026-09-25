{ pkgs, ... }:

let
  # Stock LibreTranslate runs the model once per line of a batch request. The patches
  # send the whole batch to CTranslate2 in one call: 3-5x faster on CPU, same output.
  # Written for LibreTranslate 1.9.6 / argostranslate 1.11.0; if a nixpkgs update makes
  # them fail to apply, drop `package` below to get the stock (slow) build back.
  # Only argostranslate and the few packages built on it get rebuilt.
  python = pkgs.python3.override {
    self = python;
    packageOverrides = final: prev: {
      argostranslate = prev.argostranslate.overridePythonAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./argostranslate.patch ];
      });
      libretranslate = prev.libretranslate.overridePythonAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ./libretranslate.patch ];
      });
    };
  };
in
{
  services.libretranslate = {
    enable = true;
    package = python.pkgs.toPythonApplication python.pkgs.libretranslate;
    user = "libretranslate"; # security
    group = "libretranslate";

    host = "127.0.0.1";            # listen everywhere
    port = 5389;            # listen port
    dataDir = "/var/lib/libretranslate";  # where is language models stored
    # waitress request threads: ARGOS_INTER_THREADS of them are busy with subtitle batches,
    # the spare ones keep the web UI and /languages from waiting behind a whole batch
    threads = 4;

    enableApiKeys = true;   # anti abuse
    disableWebUI = false;   # web client
    updateModels = false;   # need when new language added, better disable in other time

    domain = ""; # we don't need it, we have xray bridge
    configureNginx = false;

    extraArgs = {
      load-only = "en,ru,es,de,fr,it,pt,uk,pl,tr,zh,ja,ko,ar";
      char-limit = 20000;
      req-limit = 5; # if user without key?
      disable-files-translation = false;
      # frontend-language-source = "auto";
      # frontend-language-target = "ru";
      # no `debug = true`: it swaps waitress for Flask's single-threaded dev server
    };
  };

  systemd.services.libretranslate = {
    environment = {
      ARGOS_CHUNK_TYPE = "MINISBD"; # stanza use huggingface api which have problem with work in Russia
      # i5-7300U has 2 physical cores (4 threads): CTranslate2 runs ARGOS_INTER_THREADS translations
      # at once, ARGOS_INTRA_THREADS cores each; subtitle-translator sends PARALLEL_BATCHES requests
      # per file to keep them busy. More than the physical cores gives little on matrix math.
      ARGOS_INTER_THREADS = "2";
      ARGOS_INTRA_THREADS = "1";
      # Tokens per CTranslate2 sub-batch (~15-20 subtitle lines). Upstream default is 32,
      # which is one sentence at a time and throws the batching away; 256-512 measured best
      ARGOS_BATCH_SIZE = "256";
      # With batching, beam 2 is ~1.5x faster than the default 4 and translates a bit worse;
      # 1 is faster still, 4 for the best quality
      ARGOS_BEAM_SIZE = "2";
    };

    # Translation is background work: everything else on jedha (the xray bridge, navidrome,
    # qbittorrent...) gets the CPU first and LibreTranslate takes what is left, so it may sit
    # at 100% without slowing anything down. Against a busy neighbour it still keeps ~10% of
    # a core, so a batch finishes instead of starving until BATCH_TIMEOUT_S.
    serviceConfig = {
      CPUWeight = 10; # default 100
      CPUQuota = "300%"; # uncomment to leave one of the 4 threads idle if the laptop runs hot
    };
  };
}
