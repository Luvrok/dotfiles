{
  pkgs,
  config,
  username,
  ...
}:

{
  imports = [
    ./jedha-tunnel.nix
    ./glances.nix
    ./greenclip.nix
    ./ly.nix
  ];

  systemd.services.syncthing.environment.STNODEFAULTFOLDER = "true";

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

    ollama = (import ./ollama.nix { inherit pkgs; });
    pipewire = (import ./pipewire.nix { });
    syncthing = (import ./syncthing.nix { inherit username; });
    xserver = (import ./xserver.nix { inherit config pkgs username; });
    yggdrasil = (import ./yggdrasil.nix { });
    fstrim = {
      enable = true;
      interval = "weekly";
    };
  };
}
