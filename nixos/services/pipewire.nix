{ ... }:

{
  enable = true;
  alsa.enable = true;
  alsa.support32Bit = true;
  pulse.enable = true;
  wireplumber.enable = true;
  wireplumber.extraConfig."10-default-sink-usb-headphones" = {
    "monitor.alsa.rules" = [
      # Headphones (default)
      {
        matches = [
          {
            "media.class" = "Audio/Sink";
            "node.name" = "alsa_output.usb-Generic_USB_Audio-00.HiFi__Headphones__sink";
          }
        ];
        actions = {
          update-props = {
            "priority.session" = 900;
            "priority.driver"  = 900;
            "node.autoconnect" = true;
            "node.pause-on-idle" = false;
          };
        };
      }

      # Speakers (second)
      {
        matches = [
          {
            "media.class" = "Audio/Sink";
            "node.name" = "alsa_output.usb-Generic_USB_Audio-00.HiFi__Speaker__sink";
          }
        ];
        actions = {
          update-props = {
            "priority.session" = 1200;
            "priority.driver"  = 1200;
            "node.autoconnect" = true;
            "node.pause-on-idle" = false;
          };
        };
      }
    ];
  };
}
