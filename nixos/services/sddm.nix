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

  # weston (libinput) takes only the input devices udev has processed. the
  # kernel finds the usb devices at ~2 s, udev gets to them seconds after the
  # greeter shows, it didn't type then. so the greeter waits until udev's
  # database has a keyboard, 20 s at most. the /dev link alone isn't enough:
  # it can stay from the initrd while the database is cleared at switch-root
  systemd.services.display-manager.preStart = ''
    for _ in {1..100}; do
      for k in /dev/input/by-path/*-event-kbd; do
        udevadm info --query=property "$k" 2>/dev/null \
          | grep -q '^ID_INPUT_KEYBOARD=1$' && break 2
      done
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
