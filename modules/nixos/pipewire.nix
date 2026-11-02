{ pkgs, ... }:

{
  enable = true;
  alsa.enable = true;
  alsa.support32Bit = true;
  pulse.enable = true;
  wireplumber.enable = true;
  configPackages = [ pkgs.deepfilternet ];
  extraLadspaPackages = [ pkgs.deepfilternet ];
  extraConfig = {
    pipewire = {
      "90-defaults" = {
        "context.properties" = {
          "clock.power-of-two-quantum" = true;
          "core.daemon" = true;
          "core.name" = "pipewire-0";
          "link.max-buffers" = 16;
          "settings.check-quantum" = true;

          "default.clock.rate" = 96000;
          "default.clock.allowed-rates" = [
            44100
            48000
            88200
            96000
            192000
            352800
            384000
          ];
          "default.clock.quantum" = 256;
          "default.clock.min-quantum" = 32;
          "default.clock.max-quantum" = 4096;
        };
        "stream.properties" = {
          "resample.quality" = 10;
        };
      };

      "90-disable-bell" = {
        "context.properties" = {
          "module.x11.bell" = false;
        };
      };
    };

    pipewire-pulse = {
      "90-defaults" = {
        "context.spa-libs" = {
          "audio.convert.*" = "audioconvert/libspa-audioconvert";
          "support.*" = "support/libspa-support";
        };

        "stream.properties" = {
          "resample.quality" = 10;
        };

        "pulse.properties" = {
          "server.address" = [ "unix:native" ];
        };
      };
    };

    pipewire."99-input-denoising" = {
      "context.modules" = [
        {
          "name" = "libpipewire-module-filter-chain";
          "args" = {
            "node.description" = "DeepFilter Noise Cancelling Source";
            "media.name" = "DeepFilter Noise Cancelling Source";
            "filter.graph" = {
              "nodes" = [
                {
                  "type" = "ladspa";
                  "name" = "DeepFilter Mono";
                  "plugin" = "libdeep_filter_ladspa";
                  "label" = "deep_filter_mono";
                  "control" = {
                    "Attenuation Limit (dB)" = 100;
                  };
                }
              ];
            };
            "audio.rate" = 48000;
            "capture.props" = {
              "node.name" = "deep_filter_mono_input";
              "node.passive" = true;
            };
            "playback.props" = {
              "node.name" = "deep_filter_mono_output";
              "media.class" = "Audio/Source";
            };
          };
        }
      ];
    };
  };

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
            "priority.driver" = 900;
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
            "priority.driver" = 1200;
            "node.autoconnect" = true;
            "node.pause-on-idle" = false;
          };
        };
      }
    ];
  };

  # names for the menus (quickshell's audio menu, pavucontrol): the
  # speakers are on the monitor, "Speaker" of the usb card is the
  # motherboard's back output. the usb card's front jack takes that one away
  # while headphones are in it
  wireplumber.extraConfig."20-sink-names" = {
    "monitor.alsa.rules" = [
      {
        matches = [
          {
            "media.class" = "Audio/Sink";
            "node.description" = "~Navi 31 HDMI.*";
          }
        ];
        actions.update-props."node.description" = "Колонки (монитор)";
      }
      {
        matches = [ { "node.name" = "alsa_output.usb-Generic_USB_Audio-00.HiFi__Headphones__sink"; } ];
        actions.update-props."node.description" = "Наушники";
      }
      {
        matches = [ { "node.name" = "alsa_output.usb-Generic_USB_Audio-00.HiFi__Speaker__sink"; } ];
        actions.update-props."node.description" = "Задний выход (материнка)";
      }
    ];
  };
}
