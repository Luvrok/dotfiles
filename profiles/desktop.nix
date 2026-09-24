# Workstations with X11 + dwm.
{ config, lib, ... }:

let
  on = lib.mkDefault true;
in
{
  options.galaxy.profiles.desktop.enable = lib.mkEnableOption "the desktop profile";

  config = lib.mkIf config.galaxy.profiles.desktop.enable {
    galaxy = {
      home.enable = on;
      users.desktop.enable = on;
      security.desktop.enable = on;
      sops.enable = on;
      boot.systemdBoot.enable = on;
      boot.pinKernel = on;

      network = {
        client.enable = on;
        wifi.enable = on;
        interfaces = lib.mkDefault {
          "10-eth" = {
            match.Name = "enp14s0";
            metric = 20;
          };
          "20-wifi" = {
            match.Name = "wlan0";
            metric = 10;
          };
        };
        tcpPorts = lib.mkDefault [
          7777 # terraria
          8384 # syncthing gui
          22000 # syncthing
          61208 # glances
        ];
        udpPorts = lib.mkDefault [
          7777 # terraria
          21027 # syncthing discovery
          22000 # syncthing
        ];
      };

      desktop = {
        session.enable = on;
        packages.enable = on;
        xserver.enable = on;
        dwm.enable = on;
        picom.enable = on;
        sddm.enable = on;
        pipewire.enable = on;
        fonts.enable = on;
        dunst.enable = on;
        redshift.enable = on;
        flameshot.enable = on;
        greenclip.enable = on;
        statusbar.enable = on;
        udevil.enable = on;
      };

      hardware.qmk.enable = on;

      programs = {
        kitty.enable = on;
        zsh.enable = on;
        neovim.enable = on;
        rofi.enable = on;
        rofi-pass.enable = on;
        rofi-bluetooth.enable = on;
        rofi-audio.enable = on;
        rofi-recording.enable = on;
        rofi-translate.enable = on;
        librewolf.enable = on;
        yazi.enable = on;
        mpv.enable = on;
        zathura.enable = on;
        git.enable = on;
        gpg.enable = on;
        pass-secret-service.enable = on;
        element.enable = on;
        shell-proxy.enable = on;
        webcam.enable = on;
        virtualisation.enable = on;
      };

      services = {
        zapret.enable = on;
        syncthing.enable = on;
        jedha-tunnel.enable = on;
      };
    };
  };
}
