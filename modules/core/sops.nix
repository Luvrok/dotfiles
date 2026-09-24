{ config, lib, ... }:

let
  cfg = config.galaxy.sops;
in
{
  options.galaxy.sops = {
    enable = lib.mkEnableOption "sops-nix secrets";

    file = lib.mkOption {
      type = lib.types.path;
      default = ../../secrets/barnard.yaml;
    };

    useHostKey = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Decrypt with the SSH host key instead of a generated age key.";
    };
  };

  config = lib.mkIf cfg.enable {
    sops = {
      defaultSopsFile = cfg.file;
      defaultSopsFormat = "yaml";

      age =
        if cfg.useHostKey then
          { sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]; }
        else
          {
            keyFile = "/var/lib/sops-nix/key.txt";
            generateKey = true;
          };
    };
  };
}
