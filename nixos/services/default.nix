{
  pkgs,
  ...
}:

{
  imports = [
    ./jedha-tunnel.nix
    ./sddm.nix
    ./syncthing.nix
    ./llama-swap
    ./llama-swap/searxng.nix
    ./rgb-off.nix
  ];

  services = {
    vnstat.enable = true;
    devmon.enable = true;
    displayManager.defaultSession = "hyprland";
    blueman.enable = true;
    # journald.console = "/dev/tty4";
    earlyoom.enable = true;
    thermald.enable = true;
    rgb-off.enable = true;

    logind.settings.Login = {
      HandlePowerKey = "ignore";
      HandlePowerKeyLongPress = "poweroff";
    };

    dbus = {
      enable = true;
      implementation = "broker";
    };

    pipewire = (import ./pipewire.nix { inherit pkgs; });
    fstrim = {
      enable = true;
      interval = "weekly";
    };
  };
}
