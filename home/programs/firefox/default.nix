{ pkgs, system, pkgs-pinned, config, inputs, ... }:

let
  baseDir = "${config.home.homeDirectory}/.mozilla/firefox";
  settings = import ./settings.nix { inherit system pkgs; };

  extension = shortId: extension_id: {
    name = extension_id;
    value = {
      install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
      installation_mode = "normal_installed";
      allowed_in_private_browsing = true;
    };
  };
in
{
  imports = [ inputs.textfox.homeManagerModules.default ];

  textfox = {
    enable = true;
    profiles = ["life" "work"];

    config = {
      background = {
        color = "#282828";
      };

      border = {
        width = "1px";
        transition = "0.3s ease";
        radius = "0px";
      };

      displayWindowControls = true;
      displayNavButtons = true;
      displayUrlbarIcons = true;
      displaySidebarTools = false;
      displayTitles = false;

      font = {
        family = "JetBrainsMonoNL NFP";
        size = "14px";
      };

      tabs = {
        horizontal.enable = false;
        vertical.enable = true;
      };

      icons = {
        toolbar.extensions.enable = false;
        context.extensions.enable = false;
        context.firefox.enable = false;
      };

      extraConfig = "
        #sidebar-button {
          padding-left: 0px !important;
        }

        toolbarpaletteitem[place=\"toolbar\"][id^=\"wrapper-customizableui-special-spring\"], toolbarspring {
          max-width: 142.5px !important;
        }

        #tabbrowser-tabbox {
          padding: 0 !important;
        }

        #urlbar > .urlbar-background {
          border: 0 !important;
        }

        #customizableui-special-spring1 {
          flex: 38 80 !important;
        }

        :root {
          --tf-accent: #d65d0e !important;
          --tf-border: #3c3836 !important;
        }

        #tabbrowser-tabbox {
          &:hover {
            border-color: var(--tf-border) !important;
          }
        }

        #tabbrowser-tabbox {
          margin: 8px 8px 8px 0px !important;
        }
      ";
    };
  };

  programs.firefox = {
    enable = true;
    package = pkgs.firefox;

    nativeMessagingHosts = with pkgs; [
      vdhcoapp
      ff2mpv-rust
    ];

    policies = {
      DisableTelemetry = true;
      DisablePocket = true;
      DisableFirefoxStudies = true;

      DNSOverHTTPS = {
        Enabled = true;
        ProviderUrl = "dns.quad9.net";
        Locked = true;
        Fallback = true;
      };

      EnableTrackingProtection = {
        Value = true;
        Locked = true;
        Cryptomining = true;
        EmailTracking = true;
        Fingerprinting = true;
      };

      NetworkPrediction = false;
      OfferToSaveLogins = false;
      PasswordManagerEnabled = false;
      PostQuantumKeyAgreementEnabled = true;

      ExtensionSettings = {

      } //
      builtins.listToAttrs [
        # (extension "markdown-here" "markdown-here-webext@adam.pritchard")
        (extension "sidebery" "{3c078156-979c-498b-8990-85f7987dd929}")
        (extension "sponsorblock" "sponsorBlocker@ajay.app")
        (extension "ublock-origin" "uBlock0@raymondhill.net")
        # (extension "userchrome-toggle-extended" "userchrome-toggle-extended@n2ezr.ru")
        # (extension "decentraleyes" "jid1-BoFifL9Vbdl2zQ@jetpack")
        (extension "privacy-badger17" "jid1-MnnxcxisBPnSXQ@jetpack")
        # (extension "traduzir-paginas-web" "{036a55b4-5e72-4d05-a06c-cba2dfcc134a}")
        (extension "remove-youtube-shorts" "{2766e9f7-7bf2-4c72-81b9-d119eb54c753}")
        # (extension "clearurls" "{74145f27-f039-47ce-a470-a662b129930a}")
        (extension "simple-translate" "simple-translate@sienori")
        # (extension "port-authority" "{6c00218c-707a-4977-84cf-36df1cef310f}")
        # (extension "canvasblocker" "CanvasBlocker@kkapsner.de")
        # (extension "dont-track-me-google1" "dont-track-me-google@robwu.nl")
        (extension "gruvboxtheme" "{fd4fdeb0-5a65-4978-81c5-3488d4d56426}")
        (extension "styl-us" "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}")
        (extension "foxyproxy-standard" "foxyproxy@eric.h.jung")
        (extension "video-downloadhelper" "{b9db16a4-6edc-47ec-a1f4-b86292ed211d}")
        # (extension "" "")
        (extension "immersive-translate" "{5efceaa7-f3a2-4e59-a54b-85319448e305}")
      ];
    };

    profiles = {
      "life" = {
        id = 0;
        isDefault = true;
        settings = settings.settings // { };

        search = {
          default = "ddg";
          force = true;
          engines = settings.engines // { };
        };
      };
      "work" = {
        id = 1;
        settings = settings.settings // { };

        search = {
          default = "ddg";
          force = true;
          engines = settings.engines // { };
        };
      };
    };
  };
}
