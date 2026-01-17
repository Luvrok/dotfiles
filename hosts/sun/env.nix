{ config, pkgs, lib, ... }:

{
  imports = [
    ../../nixos/config/dash.nix
  ];

  environment.sessionVariables = {
    XFT_DPI = "192";

    QT_AUTO_SCREEN_SCALE_FACTOR = "1";
    QT_SCALE_FACTOR = "1";
    QT_SCREEN_SCALE_FACTORS = "2;2";
    _JAVA_AWT_WM_NONREPARENTING = "1";
  };

  environment.etc."X11/xorg.conf.d/00-keyboard.conf".text = ''
    Section "InputClass"
      Identifier "system-keyboard"
      MatchIsKeyboard "on"
      Option "XkbLayout" "us,ru"
      Option "XkbOptions" "grp:win_space_toggle"
    EndSection
  '';

  environment.etc."X11/xorg.conf.d/10-nvidia.conf".text = ''
    Section "ServerLayout"
      Identifier "layout"
      Screen 0 "intel"
      Inactive "nvidia"
    EndSection

    Section "Device"
      Identifier "nvidia"
      Driver "nvidia"
      BusID "PCI:1:0:0"
      Option "PrimaryGPU" "false"
    EndSection

    Section "Screen"
      Identifier "nvidia"
      Device "nvidia"
    EndSection

    Section "Device"
      Identifier "intel"
      Driver "modesetting"
      BusID "PCI:0:2:0"
      Option "TearFree" "true"
    EndSection

    Section "Screen"
      Identifier "intel"
      Device "intel"
    EndSection
  '';

  environment.etc."X11/xorg.conf.d/50-touchpad.conf".text = ''
    Section "InputClass"
      Identifier "touchpad"
      Driver "libinput"
      MatchIsTouchpad "on"
      Option "Tapping" "on"
      Option "AccelSpeed" "0.7"
      Option "NaturalScrolling" "false"
    EndSection
  '';

  environment.etc."X11/xorg.conf.d/60-monitor.conf".text = ''
    Section "Monitor"
      Identifier "eDP-1"
      Option "PreferredMode" "3456x2160"
      Option "Position" "0 0"
      Option "DPI" "192 x 192"
      Option "Primary" "true"
    EndSection
  '';
}
