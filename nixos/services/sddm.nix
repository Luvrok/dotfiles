{ pkgs, inputs, ... }:
let
  variant = "gruvbox";

  voidsddm = pkgs.runCommandLocal "void-sddm-${variant}" { } ''
    d=$out/share/sddm/themes/VoidSDDM
    mkdir -p $d
    cp -r ${inputs.voidsddm}/* $d/
    chmod -R u+w $d
    substituteInPlace $d/metadata.desktop \
      --replace 'ConfigFile=configs/default.conf' 'ConfigFile=configs/${variant}.conf'
  '';
in
{
  environment.systemPackages = [ voidsddm ];

  # the greeter (weston) only sees input devices udev is done with. udev is
  # busy for some seconds after the greeter shows (the usb devices, eth0's
  # rename), the keyboard didn't type then. so the greeter waits for udev
  systemd.services.display-manager = {
    wants = [ "systemd-udev-settle.service" ];
    after = [ "systemd-udev-settle.service" ];
  };

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    package = pkgs.kdePackages.sddm;
    theme = "VoidSDDM";
    extraPackages = with pkgs.kdePackages; [ qtsvg ];
  };
}
