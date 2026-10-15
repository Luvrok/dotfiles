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

  environment.etc."i3blocks.conf".source = ./i3/i3blocks.conf;

  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

  environment.systemPackages = [ sd-cpp ];

  systemd.services.llama-swap = {
    path = [
      pkgs.llama-cpp
      sd-cpp
    ];

    restartTriggers = [ config.environment.etc."llama-swap/config.yaml".source ];

    serviceConfig = {
      ExecStart = lib.mkForce (
        lib.escapeShellArgs [
          (lib.getExe config.services.llama-swap.package)
          "--listen=${config.services.llama-swap.listenAddress}:${toString config.services.llama-swap.port}"
          "--config=/etc/llama-swap/config.yaml"
        ]
      );

      SupplementaryGroups = [
        "render"
        "video"
      ];

      PrivateDevices = lib.mkForce false;
      MemoryDenyWriteExecute = lib.mkForce false;
      MemorySwapMax = "0";
    };
  };

  environment.etc."llama-swap/config.yaml".source = ./llama-swap/config.yaml;

  services = {
    vnstat.enable = true;
    devmon.enable = true;
    displayManager.defaultSession = "none+i3";
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
    llama-swap = {
      enable = true;
      port = 11434;
    };
    fstrim = {
      enable = true;
      interval = "weekly";
    };
  };
}
