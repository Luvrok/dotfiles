{
  pkgs,
  config,
  username,
  lib,
  ...
}:

let
  sd-cpp = pkgs.stable-diffusion-cpp.override { vulkanSupport = true; };
in
{
  imports = [
    ./jedha-tunnel.nix
    ./greenclip.nix
    ./sddm.nix
    ./searxng.nix
    ./librechat.nix
  ];

  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

  systemd.services.llama-swap = {
    # llama-swap starts `llama-server` from cmd, so it must be in PATH
    path = [
      pkgs.llama-cpp
      sd-cpp
    ];

    # Restart the service when the config changes on rebuild
    restartTriggers = [ config.environment.etc."llama-swap/config.yaml".source ];

    serviceConfig = {
      ExecStart = lib.mkForce (
        lib.escapeShellArgs [
          (lib.getExe config.services.llama-swap.package)
          "--listen=${config.services.llama-swap.listenAddress}:${toString config.services.llama-swap.port}"
          "--config=/etc/llama-swap/config.yaml"
        ]
      );

      # GPU access for the sandboxed service user
      SupplementaryGroups = [
        "render"
        "video"
      ];
      PrivateDevices = lib.mkForce false;

      # llama.cpp JIT-compiles GPU kernels, fails with this on
      MemoryDenyWriteExecute = lib.mkForce false;

      # Model in swap = unusable speed
      MemorySwapMax = "0";
    };
  };

  environment.etc."llama-swap/config.yaml".source = ./llama-swap/config.yaml;

  services = {
    vnstat.enable = true;
    devmon.enable = true;
    displayManager.defaultSession = "none+dwm";
    blueman.enable = true;
    journald.console = "/dev/tty4";
    earlyoom.enable = true;
    thermald.enable = true;

    logind.settings.Login = {
      HandlePowerKey = "ignore";
      HandlePowerKeyLongPress = "poweroff";
    };

    dbus = {
      enable = true;
      implementation = "broker";
    };

    pipewire = (import ./pipewire.nix { inherit pkgs; });
    xserver = (import ./xserver.nix { inherit config pkgs username; });
    syncthing = (import ./syncthing.nix { inherit username; });
    open-webui = (import ./open-webui { inherit pkgs; });
    llama-swap = {
      enable = true;
      port = 11434;
      # listenAddress defaults to localhost; set "0.0.0.0" + open firewall for LAN access
    };
    fstrim = {
      enable = true;
      interval = "weekly";
    };
  };
}
