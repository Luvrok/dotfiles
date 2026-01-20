{ pkgs, config, username, ... }:

{
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

    displayManager.ly = (import ./ly.nix { inherit pkgs; });
    pipewire = (import ./pipewire.nix { });
    syncthing = (import ./syncthing.nix { inherit username; });
    xserver = (import ./xserver.nix { inherit config pkgs username; });
    greenclip.enable = true;
  };

  # todo: via for some reason cant find filechooser, this config can help, but via still dont work at all. need to figure it out.
  # also monero gui cant find filechooser as well, and this config doesnt help, maybe its not about xdg actually, need to check also
  xdg.portal = {
    enable = true;
    config = {
      common = {
        default = ["gtk"];
        "org.freedesktop.portal.FileChooser" = "gtk";
      };
    };
    xdgOpenUsePortal = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
  };
}
