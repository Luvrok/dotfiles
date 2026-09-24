# Main desktop: AMD GPU, two 1440p monitors, local LLMs.
{
  imports = [ ./hardware-configuration.nix ];

  galaxy.host = {
    gpu = "amd";
    dpi = "low";
    monitors = [
      {
        output = "DisplayPort-1";
        primary = true;
        mode = "2560x1440";
        rate = 120;
      }
      {
        output = "DisplayPort-0";
        mode = "2560x1440";
        rate = 120;
        leftOf = "DisplayPort-1";
        greeter = false;
      }
    ];
  };

  galaxy.profiles.desktop.enable = true;
  galaxy.files.mutable = true;

  galaxy.services.llm.enable = true;
  galaxy.services.searxng.enable = true;

  galaxy.desktop.xserver.monitorConfig = ''
    Section "Monitor"
        Identifier "DisplayPort-0"
        Modeline "2560x1440R" 497.25 2560 2608 2640 2720 1440 1443 1448 1525 +hsync -vsync
        Option "PreferredMode" "2560x1440R"
        Option "Position" "0 0"
    EndSection

    Section "Monitor"
        Identifier "DisplayPort-1"
        Modeline "2560x1440R" 497.25 2560 2608 2640 2720 1440 1443 1448 1525 +hsync -vsync
        Option "PreferredMode" "2560x1440R"
        Option "Position" "2560 0"
        Option "Primary" "true"
    EndSection
  '';
}
