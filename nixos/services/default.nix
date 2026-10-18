{
  pkgs,
  ...
}:

{
  imports = [
    ./jedha-tunnel.nix
    ./greenclip.nix
    ./sddm.nix
    ./syncthing.nix
    ./xserver.nix
    ./i3
    ./llama-swap
    ./llama-swap/searxng.nix
  ];

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
    fstrim = {
      enable = true;
      interval = "weekly";
    };
  };
}
