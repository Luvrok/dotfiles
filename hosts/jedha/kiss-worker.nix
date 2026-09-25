{ config, ... }:
{
  imports = [ ../../modules/kiss-worker.nix ];

  sops.secrets."kiss-worker/env" = { };

  services.kiss-worker = {
    enable = true;
    port = 8291;
    environmentFile = config.sops.secrets."kiss-worker/env".path;
  };
}
