# galaxy.files.home: files linked into $HOME through home-manager.
# With mutable = true, files from this repo link to the checkout at repoPath,
# so edits apply without a rebuild. Generated files always come from the store.
{
  config,
  lib,
  self,
  ...
}:

let
  inherit (lib) mkOption types;
  cfg = config.galaxy.files;
  root = toString self;

  inRepo = src: lib.hasPrefix "${root}/" (toString src);
  toRepo = src: cfg.repoPath + lib.removePrefix root (toString src);
in
{
  options.galaxy.files = {
    mutable = mkOption {
      type = types.bool;
      default = false;
    };

    repoPath = mkOption {
      type = types.str;
      default = "/home/${config.galaxy.host.user}/HOME/infra/dotfiles";
      description = "Checkout of this repo, used when mutable = true.";
    };

    home = mkOption {
      type = types.attrsOf types.path;
      default = { };
      description = "Files to link, keyed by path relative to $HOME. Use galaxy.lib.linkTree for folders.";
    };
  };

  config = lib.mkIf (cfg.home != { }) {
    home-manager.users.${config.galaxy.host.user} =
      { config, ... }:
      {
        home.file = lib.mapAttrs (_: src: {
          source =
            if cfg.mutable && inRepo src then config.lib.file.mkOutOfStoreSymlink (toRepo src) else src;
        }) cfg.home;
      };
  };
}
