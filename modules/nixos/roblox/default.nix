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
#   netns   only roblox goes through a proxy, udp too (the game is udp, an
#           http_proxy env or proxychains don't carry it). tun2socks makes a
#           tun device from the socks5 inbound (xray's mixed one, it needs
#           "udp": true) and the device lives in the network namespace
#           "roblox". the apps start there with roblox-player and
#           roblox-studio, the rest of the system is not touched. the dns
#           of the namespace is dnsServer, it goes through the proxy too
#
# sober is not approved by roblox, an update on their side can break it
{
  config,
  lib,
  pkgs,
  username,
  ...
}:

let
  cfg = config.dotfiles.roblox;
  soberId = "org.vinegarhq.Sober";

  ns = "roblox";
  dev = "rbx0";
  ip = lib.getExe' pkgs.iproute2 "ip";

  # the device is made by tun2socks in the host namespace (so its socket to
  # the proxy goes the normal way) and then moved into the namespace, the
  # fd stays with tun2socks
  nsUp = pkgs.writeShellScript "roblox-netns-up" ''
    for _ in $(seq 100); do
      [ -e /sys/class/net/${dev} ] && break
      sleep 0.1
    done
    ${ip} link set ${dev} netns ${ns}
    ${ip} -n ${ns} link set lo up
    ${ip} -n ${ns} addr add 198.18.0.1/15 dev ${dev}
    ${ip} -n ${ns} link set ${dev} up
    ${ip} -n ${ns} route add default dev ${dev}
  '';

  # root, only through the sudo rule below: starts the namespace and runs the
  # command in it as the user who called sudo. the environment is passed as
  # arguments (env VAR=..), sudo's own is clean
  nsRun = pkgs.writeShellScript "roblox-ns-run" ''
    set -eu
    : "''${SUDO_UID:?run it with sudo}" "''${SUDO_GID:?run it with sudo}"
    [ "$SUDO_UID" != 0 ] || { echo "not for root" >&2; exit 1; }
    ${pkgs.systemd}/bin/systemctl start roblox-netns.service
    exec ${ip} netns exec ${ns} ${pkgs.util-linux}/bin/setpriv \
      --reuid="$SUDO_UID" --regid="$SUDO_GID" --init-groups -- "$@"
  '';

  # the user's side: what the apps need from the session goes as arguments
  roblox-run = pkgs.writeShellApplication {
    name = "roblox-run";
    text = ''
      vars=()
      for v in HOME PATH LANG XDG_RUNTIME_DIR XDG_DATA_DIRS XDG_CONFIG_DIRS \
               XDG_SESSION_TYPE XDG_CURRENT_DESKTOP WAYLAND_DISPLAY DISPLAY \
               XAUTHORITY DBUS_SESSION_BUS_ADDRESS; do
        if [ -n "''${!v-}" ]; then vars+=("$v=''${!v}"); fi
      done
      exec sudo ${nsRun} env "''${vars[@]}" "$@"
    '';
  };

  roblox-player = pkgs.writeShellScriptBin "roblox-player" ''
    exec ${lib.getExe roblox-run} flatpak run ${soberId} "$@"
  '';
  roblox-studio = pkgs.writeShellScriptBin "roblox-studio" ''
    exec ${lib.getExe roblox-run} vinegar "$@"
  '';
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
    netns = {
      enable = lib.mkEnableOption "roblox-player and roblox-studio, they go through the socks5 proxy";
      socks = lib.mkOption {
        type = lib.types.str;
        default = "127.0.0.1:10808";
        description = "the socks5 inbound with udp on, host:port";
      };
      dnsServer = lib.mkOption {
        type = lib.types.str;
        default = "1.1.1.1";
        description = "the dns of the namespace, asked through the proxy";
      };
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

      (lib.mkIf cfg.netns.enable {
        # ip netns exec puts these over /etc in the namespace
        environment.etc."netns/${ns}/resolv.conf".text = "nameserver ${cfg.netns.dnsServer}\n";

        systemd.services.roblox-netns = {
          description = "tun2socks of the roblox namespace";
          # xray, when the host has it. the service starts at the first
          # roblox-player or roblox-studio and stays
          after = [ "xray.service" ];
          serviceConfig = {
            ExecStartPre = [
              "-${ip} netns add ${ns}"
            ];
            ExecStart = "${lib.getExe pkgs.tun2socks} --device tun://${dev} --proxy socks5://${cfg.netns.socks} --loglevel warn";
            ExecStartPost = nsUp;
            ExecStopPost = "-${ip} netns del ${ns}";
            Restart = "on-failure";
            RestartSec = 5;
          };
        };

        security.sudo.extraRules = [
          {
            users = [ username ];
            commands = [
              {
                command = "${nsRun}";
                options = [ "NOPASSWD" ];
              }
            ];
          }
        ];

        environment.systemPackages = [
          roblox-run
          roblox-player
          roblox-studio
        ];
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
