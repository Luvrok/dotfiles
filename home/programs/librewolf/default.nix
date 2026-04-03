{ pkgs, system, config, lib, inputs, ... }:

let
  settings = import ./settings.nix { inherit system pkgs; };

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

  browsers = {
    firefox = {
      profileDir = ".mozilla/firefox";
      profiles = profiles;
    };

    librewolf = {
      profileDir = ".librewolf";
      profiles = profiles;
    };
  };

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
      (extension "sidebery" "{3c078156-979c-498b-8990-85f7987dd929}")
      (extension "vimium-ff" "{d7742d87-e61d-4b78-b8a1-b469842139fa}")
      (extension "sponsorblock" "sponsorBlocker@ajay.app")
      (extension "ublock-origin" "uBlock0@raymondhill.net")
      (extension "privacy-badger17" "jid1-MnnxcxisBPnSXQ@jetpack")
      (extension "remove-youtube-shorts" "{2766e9f7-7bf2-4c72-81b9-d119eb54c753}")
      (extension "simple-translate" "simple-translate@sienori")
      (extension "gruvboxtheme" "{fd4fdeb0-5a65-4978-81c5-3488d4d56426}")
      (extension "styl-us" "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}")
      (extension "foxyproxy-standard" "foxyproxy@eric.h.jung")
      (extension "video-downloadhelper" "{b9db16a4-6edc-47ec-a1f4-b86292ed211d}")
      (extension "immersive-translate" "{5efceaa7-f3a2-4e59-a54b-85319448e305}")
      (extension "port-authority" "{6c00218c-707a-4977-84cf-36df1cef310f}")
      (extension "mtab" "contact@maxhu.dev")
    ];
  };

  nativeMessagingHosts = with pkgs; [
    ff2mpv-rust
  ];

  extension = shortId: extension_id: {
    name = extension_id;
    value = {
      install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
      installation_mode = "normal_installed";
      allowed_in_private_browsing = true;
    };
  };

  customKeys = {
    key_close = {
      modifiers = "alt";
      key = "N";
    };

    key_cut = {};
    key_switchTextDirection = {};

    key_redo = {
      modifiers = "accel";
      key = "Y";
    };

    viewBookmarksSidebarKb = {};
    viewGenaiChatSidebarKb = {};
    key_toggleReaderMode = {};
    key_showAllTabs = {};
    key_sanitize = {};
    manBookmarkKb = {};
    addBookmarkAsKb = {};
    bookmarkAllTabsKb = {};
    key_viewInfo = {};
    key_closeWindow = {};
    key_savePage = {};
    printKb = {};
    key_quitApplication = {};
    key_quickRestart = {};
    key_findAgain = {};
    key_jsdebugger = {};

    goBackKb = {
      modifiers = "alt";
      key = "H";
    };

    goForwardKb = {
      modifiers = "alt";
      key = "L";
    };

    goHome = {
      modifiers = "shift";
      keycode = "VK_HOME";
    };

    key_reload2 = {};
    key_reload_skip_cache2 = {};
  };

  in
{
  imports = [
    inputs.textfoxy.homeManagerModules.default
  ];

  textfoxy = {
    enable = true;

    browsers = {
      librewolf = {
        enable = true;
        profiles = ["life" "work"];
      };

      firefox = {
        enable = true;
        profiles = ["life" "work"];
      };
    };

    config = {
      background.color = "#282828";

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
        family = "JetBrainsMonoNL Nerd Font Propo";
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

      extraConfig = ''
        :root {
          --tf-accent: #d65d0e !important;
          --tf-border: #3c3836 !important;
        }

        #tabbrowser-tabbox:hover {
          border-color: var(--tf-border) !important;
        }

         #sidebar-button {
          padding-left: 0px !important;
        }

        #sidebar-box {
          margin: 8px 0px 8px 8px !important;
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
      '';
    };
  };

  home.file = lib.mkMerge (
    lib.flatten (
      lib.mapAttrsToList (_browserName: browser:
        lib.mapAttrsToList (profileName: _: {
          "${browser.profileDir}/${profileName}/customKeys.json".text =
            builtins.toJSON customKeys;
        }) browser.profiles
      ) browsers
    )
  );

  programs.librewolf = {
    enable = true;
    inherit policies profiles nativeMessagingHosts;
  };

  programs.firefox = {
    enable = true;
    inherit policies profiles nativeMessagingHosts;
  };
}
