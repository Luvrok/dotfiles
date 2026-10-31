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

  # weston takes only the input devices udev is done with. the devices
  # behind the chipset (usb, the second nvme, ethernet) come up seconds
  # after the greeter would show, it didn't type then. so the greeter waits
  # for a keyboard, 20 s at most (by-path covers usb and laptop keyboards)
  systemd.services.display-manager.preStart = ''
    for _ in {1..100}; do
      ls /dev/input/by-path/*-event-kbd >/dev/null 2>&1 && break
      sleep 0.2
    done
  '';

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
    package = pkgs.kdePackages.sddm;
    theme = "VoidSDDM";
    extraPackages = with pkgs.kdePackages; [ qtsvg ];
  };
}
