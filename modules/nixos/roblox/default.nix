# roblox: the player, studio and the tools for making games. each part has
# its own switch, all off until the host sets dotfiles.roblox.enable
#
#   player  sober (the android client, flatpak only, closed source). the
#           windows player in wine is blocked by roblox, sober is the way
#   studio  vinegar (wine, its own prefix and wine build, nothing from
#           ../wine-gaming). the config is ~/.config/vinegar/config.toml. if
#           the docks bug, turn the virtual desktop on in vinegar's wine
#           settings
#   tools   rojo and wally (files <-> studio, packages), selene and
#           luau-lsp (lint, lsp), lune (luau scripts outside of roblox).
#           stylua is in desktop/packages.nix. the studio plugin of rojo is
#           installed with `rojo plugin install`
#
# sober is not approved by roblox, an update on their side can break it
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.dotfiles.roblox;
  soberId = "org.vinegarhq.Sober";
in
{
  options.dotfiles.roblox = {
    enable = lib.mkEnableOption "roblox: the player, studio and the tools";
    player.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "sober, the player";
    };
    studio.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "vinegar, studio in wine";
    };
    tools.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "rojo, wally, selene, luau-lsp, lune";
    };
    proxy = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "http://127.0.0.1:10808";
      description = "for flatpak's downloads of flathub, when it is blocked";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      (lib.mkIf cfg.player.enable {
        services.flatpak.enable = true;

        # flathub and sober, once: nothing happens when it's installed.
        # the update is `flatpak update`
        systemd.services.flatpak-sober = {
          description = "install sober from flathub";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          path = [ pkgs.flatpak ];
          environment = lib.mkIf (cfg.proxy != null) {
            http_proxy = cfg.proxy;
            https_proxy = cfg.proxy;
          };
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            Restart = "on-failure";
            RestartSec = "1min";
          };
          script = ''
            flatpak remote-add --system --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
            flatpak info --system ${soberId} >/dev/null 2>&1 \
              || flatpak install --system --noninteractive flathub ${soberId}
          '';
        };
      })

      (lib.mkIf cfg.studio.enable {
        # vulkan, for the 3d view of studio
        hardware.graphics = {
          enable = true;
          enable32Bit = true;
        };
        environment.systemPackages = [ pkgs.vinegar ];
      })

      (lib.mkIf cfg.tools.enable {
        environment.systemPackages = with pkgs; [
          rojo
          wally
          selene
          luau-lsp
          lune
        ];
      })
    ]
  );
}
