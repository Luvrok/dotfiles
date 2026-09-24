# One syncthing for both kinds of hosts:
# desktops run it as the main user, jedha as a system user in the media group.
{ config, lib, ... }:

let
  cfg = config.galaxy.services.syncthing;
  inherit (config.galaxy.host) user;
in
{
  options.galaxy.services.syncthing = {
    enable = lib.mkEnableOption "syncthing";

    systemUser = lib.mkOption {
      type = lib.types.bool;
      default = config.galaxy.profiles.server.enable;
      defaultText = "true on the server profile";
      description = "Run as a `syncthing` system user in the media group, data in /var/lib/syncthing.";
    };

    relay = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Use public relays when a direct connection fails.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

        services.syncthing = {
          enable = true;
          openDefaultPorts = true;

          settings.options.relaysEnabled = cfg.relay;
          # Devices and folders are managed in the web UI; don't let the
          # declarative settings above wipe them.
          overrideDevices = false;
          overrideFolders = false;
        };
      }

      (lib.mkIf (!cfg.systemUser) {
        services.syncthing = {
          inherit user;
          dataDir = "/home/${user}/.config/syncthing";
          configDir = "/home/${user}/.config/syncthing";
        };
      })

      (lib.mkIf cfg.systemUser {
        systemd.services.syncthing.serviceConfig.UMask = lib.mkForce "0002";

        users.users.syncthing = {
          isSystemUser = true;
          group = lib.mkForce "media";
        };

        services.syncthing = {
          user = "syncthing";
          dataDir = "/var/lib/syncthing";
          configDir = "/var/lib/syncthing";
        };
      })
    ]
  );
}
