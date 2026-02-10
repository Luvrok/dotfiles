{ config, pkgs, lib, inputs, username, ... }:

{
  programs.home-manager.enable = true;

  imports = [
    ./picom.nix
    ./packages.nix
    ./services
    ./programs
  ];

  home.stateVersion = "24.11";
  home.username = "${username}";
  home.homeDirectory = "/home/${username}";

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "application/pdf" = "koreader.desktop";
      "inode/directory" = [ "thunar.desktop" ];
    };
  };

  home.file.".Xresources" = {
    executable = true;
    text = ''
      ! normal
      st.normbgcolor:      #000000
      st.normbordercolor:  #3c3836
      st.normfgcolor:      #ebdbb2

      ! selected
      st.selfgcolor:       #fbf1c7
      st.selbordercolor:   #d65d0e
      st.selbgcolor:       #000000

      dwm.normbordercolor: #3c3836
      dwm.normbgcolor: #171717
      dwm.normfgcolor: #ebdbb2
      dwm.selbordercolor: #d65d0e
      dwm.selbgcolor: #d65d0e
      dwm.selfgcolor: #fbf1c7

      font: JetBrainsMonoNL Nerd Font:size=12

      ! normal
      normfgcolor:        #ebdbb2
      normbgcolor:        #171717

      ! selected
      selfgcolor:         #fbf1c7
      selbgcolor:         #d65d0e

      ! out
      outfgcolor:         #ebdbb2
      outbgcolor:         #171717

      ! border
      selbordercolor:     #d65d0e

      Xcursor.theme: Vanilla-DMZ
      Xcursor.size: 32
    '';
  };

  gtk = {
    enable = true;
    theme.package = pkgs.gruvbox-dark-gtk;
    theme.name = "gruvbox-dark";
    iconTheme = {
      package = pkgs.gruvbox-dark-icons-gtk;
      name = "gruvbox-dark";
    };
  };

  home.pointerCursor = {
    name = "Vanilla-DMZ";
    package = pkgs.vanilla-dmz;
    size = 32;
  };

  qt = {
    enable = true;
    platformTheme.name = "gtk";
  };

  home.file.".local/bin" = {
    source = ./local/sh;
    recursive = true;
    executable = true;
  };

  home.file.".local/media" = {
    source = ./local/media;
    recursive = true;
    executable = true;
  };

  home.file.".config/rofi" = {
    source = ./programs/rofi/config;
    recursive = true;
  };

  home.file.".Xmodmap".text = ''
    keycode  37 = Control_L NoSymbol Control_L
    keycode  50 = Shift_L NoSymbol Shift_L
  '';

  home.file.".config/.asoundrc".text = ''
    defaults.pcm.card 1
    defaults.ctl.card 1
  '';

  home.file.".config/pipewire/pipewire.conf.d/99-input-denoising.conf".text = ''
    context.modules = [
      {
        name = libpipewire-module-filter-chain
        args = {
          node.description =  "Noise Canceling source"
          media.name =  "Noise Canceling source"
          filter.graph = {
            nodes = [
              {
                type = ladspa
                name = rnnoise
                plugin = ${pkgs.rnnoise-plugin}/lib/ladspa/librnnoise_ladspa.so
                label = noise_suppressor_mono
                control = {
                  "VAD Threshold (%)" 95.0
                  "VAD Grace Period (ms)" 200
                  "Retroactive VAD Grace (ms)" 0
                }
              }
            ]
          }
          capture.props = {
            node.name =  "capture.rnnoise_source"
            node.passive = true
            audio.rate = 48000
          }
          playback.props = {
            node.name =  "rnnoise_source"
            media.class = Audio/Source
            audio.rate = 48000
          }
        }
      }
    ]
  '';
}
