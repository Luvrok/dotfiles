# Laptop: Intel + NVIDIA (PRIME offload), HiDPI panel.
# The machine and its user are still called "dash".
{
  imports = [ ./hardware-configuration.nix ];

  networking.hostName = "dash";

  galaxy.host = {
    user = "dash";
    gpu = "nvidia";
    dpi = "high";
    isLaptop = true;
    monitors = [
      {
        output = "eDP-1";
        primary = true;
      }
    ];
  };

  galaxy.profiles.desktop.enable = true;
  galaxy.services.zapret.testTools = false;

  galaxy.desktop.xserver.monitorConfig = ''
    Section "Monitor"
      Identifier "eDP-1"
      Option "PreferredMode" "3456x2160"
      Option "Position" "0 0"
      Option "DPI" "192 x 192"
      Option "Primary" "true"
    EndSection
  '';
}
