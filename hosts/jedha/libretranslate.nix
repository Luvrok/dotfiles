{ config, ... }:

{
  services.libretranslate = {
    enable = true;
    user = "libretranslate"; # security
    group = "libretranslate";

    host = "::";            # listen everywhere
    port = 5389;            # listen port
    dataDir = "/var/lib/libretranslate";  # where is language models stored
    threads = 4;            # processor cores

    enableApiKeys = true;   # anti abuse
    disableWebUI = false;   # web client
    updateModels = false;   # need when new language added, better disable in other time

    domain = ""; # we don't need it, we have xray bridge
    configureNginx = false;

    extraArgs = {
      load-only = "en,ru,es,de,fr,it,pt,uk,pl,tr,zh,ja,ko,ar";
      char-limit = 20000;
      req-limit = 100; # if user without key?
      disable-files-translation = true;
      # frontend-language-source = "auto";
      # frontend-language-target = "ru";
      debug = true;
    };
  };

  systemd.services.libretranslate.environment.ARGOS_CHUNK_TYPE = "MINISBD"; # stanza use huggingface api which have problem with work in Russia
}
