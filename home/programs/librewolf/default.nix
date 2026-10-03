{
  config,
  pkgs,
  lib,
  inputs,
  ...
}:

let
  cfg = import ./settings.nix { inherit pkgs; };

  # Local DoH endpoint from dnscrypt-proxy. Must match the NixOS module dnscrypt-local-doh.nix.
  localDoh = {
    url = "https://127.0.0.1:3053/dns-query";
    caCert = "/etc/dnscrypt-proxy/local-doh-ca.crt";
  };

  rofiTabs = pkgs.callPackage ./rofi-tabs-switcher.nix {
    theme = "~/.config/rofi/rofi-librewolf-menu.rasi";
  };

  mkProfile = id: {
    inherit id;
    isDefault = id == 0;
    inherit (cfg) settings;
    search = {
      default = "ddg";
      force = true;
      engines = cfg.engines;
    };
  };

  # Same profiles for LibreWolf and Firefox
  profiles = {
    life = mkProfile 0;
    work = mkProfile 1;
  };

  profileNames = lib.attrNames profiles;

  extension = shortId: extensionId: {
    name = extensionId;
    value = {
      install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
      installation_mode = "normal_installed";
      allowed_in_private_browsing = true;
    };
  };

  policies = {
    DisableTelemetry = true;
    DisableFirefoxStudies = true;
    DisableFirefoxAccounts = true;
    DisableFeedbackCommands = true;
    DontCheckDefaultBrowser = true;
    NoDefaultBookmarks = true;
    SkipTermsOfUse = true;
    NetworkPrediction = false;
    OfferToSaveLogins = false;
    PasswordManagerEnabled = false;
    VisualSearchEnabled = false;

    GenerativeAI = {
      Enabled = false;
      Locked = true;
    };

    # No tips, onboarding, feature ads or Labs from Mozilla
    UserMessaging = {
      WhatsNew = false;
      ExtensionRecommendations = false;
      FeatureRecommendations = false;
      UrlbarInterventions = false;
      SkipOnboarding = true;
      MoreFromMozilla = false;
      FirefoxLabs = false;
      Locked = true;
    };

    # Mozilla's own address bar suggestions. Search engine suggestions are separate.
    FirefoxSuggest = {
      WebSuggestions = false;
      SponsoredSuggestions = false;
      ImproveSuggest = false;
      OnlineEnabled = false;
      Locked = true;
    };

    FirefoxHome = {
      SponsoredTopSites = false;
      SponsoredStories = false;
      SponsoredPocket = false;
      Stories = false;
      Pocket = false;
      Weather = false;
      Locked = true;
    };

    EnableTrackingProtection = {
      Category = "strict";
      Locked = true;
    };

    # All browser DNS goes to dnscrypt-proxy. With Fallback off, if dnscrypt-proxy
    # is down nothing resolves, but nothing leaks to the system resolver either.
    DNSOverHTTPS = {
      Enabled = true;
      ProviderURL = localDoh.url;
      Fallback = false;
      Locked = true;
      # Local network names go through the system resolver (router and so on)
      ExcludedDomains = [
        "lan"
        "home.arpa"
      ];
    };

    # Trust the local DoH certificate
    Certificates.Install = [ localDoh.caCert ];

    ExtensionSettings = {
      "@rofi.tab.switcher" = {
        install_url = "file://${rofiTabs.xpi}/rofi-tab-switcher.xpi";
        installation_mode = "force_installed";
        allowed_in_private_browsing = true;
      };
    }
    // builtins.listToAttrs [
      (extension "foxyproxy-standard" "foxyproxy@eric.h.jung")
      (extension "kiss-translator" "{fb25c100-22ce-4d5a-be7e-75f3d6f0fc13}")
      (extension "librezam" "Librezam@Librezam")
      (extension "mtab" "contact@maxhu.dev")
      (extension "port-authority" "{6c00218c-707a-4977-84cf-36df1cef310f}")
      (extension "remove-youtube-shorts" "{2766e9f7-7bf2-4c72-81b9-d119eb54c753}")
      (extension "sidebery" "{3c078156-979c-498b-8990-85f7987dd929}")
      (extension "sponsorblock" "sponsorBlocker@ajay.app")
      (extension "styl-us" "{7a7a4a92-a2a0-41d1-9fd7-1e92480d612d}")
      (extension "ublock-origin" "uBlock0@raymondhill.net")
      (extension "youtube-recommended-videos" "myallychou@gmail.com")
      (extension "userchrome-toggle-extended" "userchrome-toggle-extended@n2ezr.ru")
      (extension "video-downloadhelper" "{b9db16a4-6edc-47ec-a1f4-b86292ed211d}")
      (extension "vimium-ff" "{d7742d87-e61d-4b78-b8a1-b469842139fa}")
      (extension "gruvboxtheme" "{fd4fdeb0-5a65-4978-81c5-3488d4d56426}")
    ];
  };

  nativeMessagingHosts = [ rofiTabs.plugin ];
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
        profiles = profileNames;
      };
      firefox = {
        enable = true;
        profiles = profileNames;
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

        #tabbrowser-tabbox {
          padding: 0 !important;

          &:hover {
            border-color: var(--tf-border) !important;
          }
        }

        #sidebar-button {
          padding-left: 0px !important;
        }

        #sidebar-box {
          margin: 8px 0px 8px 8px !important;
        }

        toolbarpaletteitem[place="toolbar"][id^="wrapper-customizableui-special-spring"],
        toolbarspring {
          max-width: 142.5px !important;
        }

        #customizableui-special-spring1 {
          flex: 38 80 !important;
        }

        #urlbar > .urlbar-background {
          border: 0 !important;
        }

        #translations-button {
          display: none !important;
        }

        findbar[hidden] {
          display: none !important;
        }
      '';
    };
  };

  # Custom keyboard shortcuts in every profile of both browsers
  home.file = lib.mkMerge (
    lib.concatMap
      (
        browser:
        map (name: {
          "${config.programs.${browser}.profilesPath}/${name}/customKeys.json".source = ./customKeys.json;
        }) profileNames
      )
      [
        "librewolf"
        "firefox"
      ]
  );

  programs.librewolf = {
    enable = true;
    inherit profiles policies nativeMessagingHosts;
  };

  programs.firefox = {
    enable = true;
    inherit profiles policies nativeMessagingHosts;
  };
}
