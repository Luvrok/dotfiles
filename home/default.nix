{ config, pkgs, lib, inputs, username, ... }:

{
  programs.home-manager.enable = true;

  imports = [
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
    };
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

  home.file.".local/bin".source = pkgs.runCommand "merge-folders" {} ''
    mkdir -p $out/sh-rofi
    mkdir -p $out/sh-others
    mkdir -p $out/sh-nixos
    cp -r ${./local/sh/sh-rofi}/* $out/sh-rofi
    cp -r ${./local/sh/sh-others}/* $out/sh-others
    cp -r ${./local/sh/sh-nixos}/* $out/sh-nixos
  '';

  home.file.".local/media".source = pkgs.runCommand "merge-folders" {} ''
    mkdir -p $out/media
    cp -r ${./local/media}/* $out
  '';

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
