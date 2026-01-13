{ pkgs, system, ... }: {
  settings = {
    # === shyfox ===
    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
    "sidebar.revamp" = false;
    "svg.context-properties.content.enabled" = true;
    "layout.css.has-selector.enabled" = true;
    "browser.urlbar.suggest.calculator" = true;
    "browser.urlbar.unitConversion.enabled" = true;
    "browser.urlbar.trimHttps" = true;
    "browser.urlbar.trimURLs" = true;
    "widget.gtk.ignore-bogus-leave-notify" = 1;
    "widget.gtk.rounded-bottom-corners.enabled" = false;

    # === GPU / Web / Media (Linux+Xorg+VAAPI) ===
    "dom.webgpu.enabled" = true;
    "gfx.webrender.all" = true;
    "layers.gpu-process.enabled" = true;
    "layers.mlgpu.enabled" = true;
    "media.ffmpeg.vaapi.enabled" = true;
    "media.ffvpx.enabled" = false;
    "media.gpu-process-decoder" = true;
    "media.navigator.mediadatadecoder_vpx_enabled" = true;
    "media.rdd-ffmpeg.enabled" = true;
    "media.rdd-vpx.enabled" = false;
    "media.gmp-widevinecdm.enabled" = true;

    # === Updates / warnings ===
    "app.update.auto" = false;
    "browser.aboutConfig.showWarning" = false;
    "browser.shell.checkDefaultBrowser" = false;

    # === Homepage / cookies ===
    "cookiebanners.service.mode" = 2;

    # === HTTPS-only ===
    "dom.security.https_only_mode" = true;
    "dom.security.https_only_mode_ever_enabled" = true;

    # === Privacy ===
    "privacy.query_stripping.enable" = true;
    "privacy.donottrackheader.enabled" = true;
    "privacy.donottrackheader.value" = 1;
    "privacy.trackingprotection.enabled" = true;
    "privacy.trackingprotection.socialtracking.enabled" = true;
    "privacy.partition.network_state.ocsp_cache" = true;
    "identity.fxaccounts.enabled" = false;
    "browser.ml.chat.enabled" = false; 
    "extensions.formautofill.addresses.enabled" = false; 
    "extensions.formautofill.creditCards.enabled" = false;
    "beacon.enabled" = false;
    "device.sensors.enabled" = false;
    "geo.enabled" = false;
    "network.security.esni.enabled" = true;
    "network.predictor.enabled" = false;
    "browser.urlbar.speculativeConnect.enabled" = false;
    "browser.urlbar.usepreloadedtopurls.enabled" = false;
    "network.ftp.enable" = false;
    "privacy.resistFingerprinting" = false;

    # === Telemetry OFF ===
    "browser.newtabpage.activity-stream.feeds.telemetry" = false;
    "browser.newtabpage.activity-stream.telemetry" = false;
    "browser.ping-centre.telemetry" = false;
    "toolkit.telemetry.archive.enabled" = false;
    "toolkit.telemetry.bhrPing.enabled" = false;
    "toolkit.telemetry.enabled" = false;
    "toolkit.telemetry.firstShutdownPing.enabled" = false;
    "toolkit.telemetry.hybridContent.enabled" = false;
    "toolkit.telemetry.newProfilePing.enabled" = false;
    "toolkit.telemetry.reportingpolicy.firstRun" = false;
    "toolkit.telemetry.shutdownPingSender.enabled" = false;
    "toolkit.telemetry.unified" = false;
    "toolkit.telemetry.updatePing.enabled" = false;
    "datareporting.healthreport.uploadEnabled" = false;
    "extensions.webcompat-reporter.enabled" = false;
    "datareporting.policy.dataSubmissionEnabled" = false;
    "browser.urlbar.eventTelemetry.enabled" = false;

    # === Experiments OFF ===
    "experiments.activeExperiment" = false;
    "experiments.enabled" = false;
    "experiments.supported" = false;
    "network.allow-experiments" = false;
    "app.normandy.enabled" = false;
    "app.shield.optoutstudies.enabled" = true;

    # === Pocket OFF ===
    "browser.newtabpage.activity-stream.section.highlights.includePocket" = false;
    "extensions.pocket.enabled" = false;
    "extensions.pocket.api" = "";
    "extensions.pocket.oAuthConsumerKey" = "";
    "extensions.pocket.showHome" = false;
    "extensions.pocket.site" = "";

    # === UI tweaks ===
    "browser.fullscreen.autohide" = false;
    "browser.newtabpage.activity-stream.topSitesRows" = 0;
    "browser.urlbar.quickactions.enabled" = true;
    "browser.search.hiddenOneOffs" = "Google,Yahoo,Bing,Amazon.com,Twitter";
    "browser.newtabpage.activity-stream.improvesearch.topSiteSearchShortcuts" = false;
    "browser.urlbar.suggest.bookmark" = false;
    "browser.urlbar.suggest.quicksuggest.nonsponsored" = false;
    "browser.urlbar.suggest.quicksuggest.sponsored" = false;
    "browser.urlbar.suggest.searches" = false;
    "browser.sessionstore.restore_on_demand" = true;
    "browser.sessionstore.restore_pinned_tabs_on_demand" = true;
    "findbar.modalHighlight" = true;
    "browser.startup.page" = 3;
    "layout.css.prefers-color-scheme.content-override" = 0;
    "intl.accept_languages" = "ru-RU, ru, en-US, en";
    "intl.locale.requested" = "ru, en-US";
    "browser.contentblocking.report.lockwise.enabled" = false;
    "extensions.fxmonitor.firstAlertShown" = false;
    "browser.uitour.enabled" = false;
    "editor.resizing.enabled_by_default" = true;
    "dom.push.enabled" = false;
    "dom.push.connection.enabled" = false;
    "dom.battery.enabled" = "false";
    "dom.event.clipboardevents.enabled" = false;
    "dom.event.contextmenu.enabled" = true;
    "devtools.chrome.enabled" = true;
    "devtools.debugger.remote-enabled" = true;

    # === Clipboard / welcome ===
    "dom.events.asyncClipboard.clipboardItem" = true;
    "trailhead.firstrun.didSeeAboutWelcome" = true;

    # === Fonts override ===
    "browser.display.use_document_fonts" = 1;

    # === Downloads / Fullscreen / Misc ===
    "browser.download.start_downloads_in_tmp_dir" = true;
    "browser.download.useDownloadDir" = false;
    "browser.download.always_ask_before_handling_new_types" = true;
    "full-screen-api.transition.timeout" = 0;
    "network.protocol-handler.external.mailto" = false;
    "signon.rememberSignons" = false;
  };

  engines = {
    "nix-packages" = {
      urls = [
        {
          template = "https://search.nixos.org/packages";
          params = [
            {
              name = "type";
              value = "packages";
            }
            {
              name = "channel";
              value = "unstable";
            }
            {
              name = "query";
              value = "{searchTerms}";
            }
          ];
        }
      ];

      icon = "${pkgs.nixos-icons}/share/icons/hicolor/scalable/apps/nix-snowflake.svg";
      definedAliases = [ "@np" ];
    };

    "nixos-wiki" = {
      urls = [ { template = "https://wiki.nixos.org/index.php?search={searchTerms}"; } ];
      icon = "https://wiki.nixos.org/favicon.png";
      updateInterval = 24 * 60 * 60 * 1000; # for icon
      definedAliases = [ "@nw" ];
    };

    "noogle-dev-search" = {
      urls = [ { template = "https://noogle.dev/?term=%22{searchTerms}%22"; } ];
      icon = "https://noogle.dev/favicon.png";
      updateInterval = 24 * 60 * 60 * 1000; # for icon
      definedAliases = [
        "@ngd"
        "@nog"
      ];
    };

    "bing".metaData.hidden = true;
    "amazonnl".metaData.hidden = true;
    "ebay".metaData.hidden = true;
    "google".metaData.alias = "@g";
  };
}
