# galaxy.expose.<service>: local services published to the internet through
# xray (reverse tunnel to a VPS) and nginx on mos-eisley.
# Other hosts read them from self.nixosConfigurations.<host>.config.galaxy.expose.
{ lib, ... }:

{
  options.galaxy.expose = lib.mkOption {
    default = { };
    type = lib.types.attrsOf (
      lib.types.submodule {
        options = {
          port = lib.mkOption { type = lib.types.port; };
          subdomain = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Public name under the nginx domain; null = tunnel only.";
          };
        };
      }
    );
  };
}
