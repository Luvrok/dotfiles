{ pkgs, ... }:

let
  privacy = {
    # Isolate third party storage per site
    "privacy.partition.always_partition_third_party_non_cookie_storage" = true;
    "privacy.partition.always_partition_third_party_non_cookie_storage.exempt_sessionstorage" = false;
    "browser.privatebrowsing.forceMediaMemoryCache" = true;
    "media.memory_cache_max_size" = 65536;
    "browser.helperApps.deleteTempFileOnExit" = true;
    "browser.formfill.enable" = false; # don't remember what I type into forms
    "browser.sessionstore.privacy_level" = 2; # session restore keeps tabs, not form data
    # Tracking params removed from links
    "privacy.query_stripping.strip_list" =
      "__hsfp __hssc __hstc __s _hsenc _openstat dclid fbclid gbraid gclid hsCtaTracking igshid mc_eid ml_subscriber ml_subscriber_hash msclkid oft_c oft_ck oft_d oft_id oft_ids oft_k oft_lk oft_sk oly_anon_id oly_enc_id rb_clickid s_cid twclid vero_conv vero_id wbraid wickedid yclid";
    # Global Privacy Control: tells sites not to sell or share my data
    "privacy.globalprivacycontrol.enabled" = true;
    "privacy.globalprivacycontrol.pbmode.enabled" = true;
    "privacy.globalprivacycontrol.functionality.enabled" = true;
    "privacy.userContext.enabled" = true; # containers
    "privacy.userContext.ui.enabled" = true;
    "identity.fxaccounts.enabled" = false; # no Firefox account or Sync
    "signon.rememberSignons" = false; # I use a separate password manager
    "signon.autofillForms" = false;
    "signon.formlessCapture.enabled" = false;
    "extensions.formautofill.addresses.enabled" = false;
    "extensions.formautofill.creditCards.enabled" = false;
  };

  location = {
    "permissions.default.geo" = 2; # block location requests without asking
    "geo.provider.network.url" = "";
    "geo.provider.use_gpsd" = false;
    "geo.provider.use_geoclue" = false;
    # No IP based region lookup by Mozilla
    "browser.region.network.url" = "";
    "browser.region.update.enabled" = false;
  };

  network = {
    "dom.security.https_only_mode" = true;
    # Don't send a plain http probe while waiting for the https version
    "dom.security.https_only_mode_send_http_background_request" = false;
    "network.auth.subresource-http-auth-allow" = 1; # no login popups from third party content
    "network.http.referer.XOriginTrimmingPolicy" = 2; # other sites only see my origin, not the full URL
    # WebRTC shows only one IP (the VPN one when it's on)
    "media.peerconnection.ice.default_address_only" = true;
    "media.peerconnection.ice.proxy_only_if_behind_proxy" = true;
    # Close ways around the proxy
    "network.gio.supported-protocols" = "";
    "network.file.disable_unc_paths" = true;
    "network.proxy.socks_remote_dns" = true; # DNS goes through the SOCKS proxy too
    # No preloading of pages or DNS I didn't ask for
    "network.dns.disablePrefetch" = true;
    "network.prefetch-next" = false;
    "network.predictor.enabled" = false;
    "network.http.speculative-parallel-limit" = 0;
    "browser.places.speculativeConnect.enabled" = false;
    "browser.urlbar.speculativeConnect.enabled" = false;
    # No background pings to Mozilla to check the connection.
    # Downside: hotel or cafe Wi-Fi login pages won't pop up by themselves.
    "network.connectivity-service.enabled" = false;
    "network.captive-portal-service.enabled" = false;
    "captivedetect.canonicalURL" = "";
  };

  security = {
    "security.cert_pinning.enforcement_level" = 2;
    "security.ssl.require_safe_negotiation" = true;
    "security.ssl.treat_unsafe_negotiation_as_broken" = true;
    # Revoked certs checked from a local list, no requests per site
    "security.pki.crlite_mode" = 2;
    "security.remote_settings.crlite_filters.enabled" = true;
    "security.OCSP.require" = true;
    "security.tls.enable_0rtt_data" = false;
    "browser.xul.error_pages.expert_bad_cert" = true; # show full details on cert errors
    "permissions.delegation.enabled" = false; # permission prompts show the real site
    "permissions.manager.defaultsUrl" = ""; # no special permissions for Mozilla sites
    "webchannel.allowObject.urlWhitelist" = "";
    "network.IDN_show_punycode" = true; # show fake lookalike domains as xn--...
    "pdfjs.enableScripting" = false; # no JavaScript inside PDFs

    # Extensions can't run on Mozilla's add-on and account sites. LW: empty
    "extensions.webextensions.restrictedDomains" =
      "accounts-static.cdn.mozilla.net,accounts.firefox.com,addons.cdn.mozilla.net,addons.mozilla.org,api.accounts.firefox.com,content.cdn.mozilla.net,discovery.addons.mozilla.org,oauth.accounts.firefox.com,profile.accounts.firefox.com,support.mozilla.org,sync.services.mozilla.com";
    "extensions.quarantinedDomains.enabled" = true; # LW: false
    "extensions.postDownloadThirdPartyPrompt" = false;
    "extensions.systemAddon.update.enabled" = false;
    "extensions.systemAddon.update.url" = "";
    "extensions.getAddons.cache.enabled" = false; # don't send my add-on list to AMO every day

    # Google Safe Browsing off. nixpkgs builds have no Google API key,
    # so it can't work here anyway. uBlock Origin covers malware domains.
    "browser.safebrowsing.malware.enabled" = false;
    "browser.safebrowsing.phishing.enabled" = false;
    "browser.safebrowsing.blockedURIs.enabled" = false;
    "browser.safebrowsing.downloads.enabled" = false;
    "browser.safebrowsing.downloads.remote.enabled" = false;
    "browser.safebrowsing.downloads.remote.url" = "";
    "browser.safebrowsing.provider.google.updateURL" = "";
    "browser.safebrowsing.provider.google.gethashURL" = "";
    "browser.safebrowsing.provider.google4.updateURL" = "";
    "browser.safebrowsing.provider.google4.gethashURL" = "";
    "browser.safebrowsing.provider.google4.dataSharingURL" = "";
  };

  # DRM is off. For Netflix or Spotify set the first two to true
  # and reset media.gmp-manager.url in about:config.
  media = {
    "media.eme.enabled" = false;
    "media.gmp-provider.enabled" = false;
    "media.gmp-manager.url" = "data:text/plain,";
    "media.gmp-gmpopenh264.enabled" = false;
    "media.webrtc.hw.h264.enabled" = true;
  };

  search = {
    # Search suggestions from the default engine (DuckDuckGo) while I type.
    # Firefox skips them when the text looks like a URL, and never in private windows.
    "browser.search.suggest.enabled" = true; # LW: false
    "browser.urlbar.suggest.searches" = true; # LW: false
    "browser.search.suggest.enabled.private" = false;
    "browser.search.update" = false;
    "browser.search.separatePrivateDefault" = true; # private windows can use another engine
    "browser.search.separatePrivateDefault.ui.enabled" = true;
    "browser.search.serpEventTelemetry.enabled" = false;
    # No Firefox Suggest, trending searches, weather, MDN or add-on tips from Mozilla
    "browser.urlbar.quicksuggest.enabled" = false;
    "browser.urlbar.addons.featureGate" = false;
    "browser.urlbar.mdn.featureGate" = false;
    "browser.urlbar.trending.featureGate" = false;
    "browser.urlbar.weather.featureGate" = false;
    "browser.urlbar.suggest.weather" = false;
    "browser.urlbar.suggest.topsites" = false; # no top sites list when I click the address bar
    "browser.urlbar.update2.engineAliasRefresh" = true; # "Add" button for custom search engines
  };

  behavior = {
    "browser.download.start_downloads_in_tmp_dir" = true;
    "browser.download.useDownloadDir" = false; # ask where to save
    "browser.download.autohideButton" = false;
    "browser.download.manager.addToRecentDocs" = false;
    "browser.download.alwaysOpenPanel" = false;
    "media.autoplay.default" = 5; # no autoplay, muted or not
    "dom.disable_window_move_resize" = true; # sites can't move or resize the window
    "browser.link.open_newwindow" = 3;
    "browser.link.open_newwindow.restriction" = 0; # popups open as tabs
    "browser.tabs.searchclipboardfor.middleclick" = false;
    "app.update.auto" = false; # updates come from nix
  };

  # Mozilla ads, promos, what's new and first run pages
  noise = {
    "browser.startup.homepage_override.mstone" = "ignore";
    "startup.homepage_override_url" = "about:blank";
    "startup.homepage_welcome_url" = "about:blank";
    "startup.homepage_welcome_url.additional" = "";
    "browser.messaging-system.whatsNewPanel.enabled" = false;
    "browser.uitour.enabled" = false;
    "browser.uitour.url" = "";
    "browser.shell.checkDefaultBrowser" = false;
    "browser.aboutConfig.showWarning" = false;
    "browser.preferences.moreFromMozilla" = false;
    "browser.topsites.useRemoteSetting" = false;
    "browser.newtabpage.activity-stream.feeds.topsites" = false;
    "browser.newtabpage.activity-stream.section.highlights.includeDownloads" = false;
    "browser.newtabpage.activity-stream.section.highlights.includeVisited" = false;
    "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
    "browser.newtabpage.activity-stream.feeds.section.topstories.options" = ''{"hidden":true}'';
    "browser.newtabpage.activity-stream.showSponsored" = false;
    "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
    "browser.newtabpage.activity-stream.default.sites" = "";
    "browser.newtabpage.activity-stream.feeds.weatherfeed" = false;
    "browser.newtabpage.activity-stream.showWeather" = false;
    "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" = false;
    "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" = false;
    "browser.contentblocking.report.lockwise.enabled" = false;
    "browser.contentblocking.report.hide_vpn_banner" = true;
    "browser.contentblocking.report.vpn.enabled" = false;
    "browser.contentblocking.report.show_mobile_app" = false;
    "browser.vpn_promo.enabled" = false;
    "browser.promo.focus.enabled" = false;
    "identity.fxaccounts.toolbar.pxiToolbarEnabled" = false;
    "extensions.htmlaboutaddons.recommendations.enabled" = false;
    "extensions.getAddons.showPane" = false;
    "extensions.webcompat-reporter.enabled" = false;
    "lightweightThemes.getMoreURL" = "";
    "browser.tabs.firefox-view" = false; # hide the Firefox View button
    "browser.translations.automaticallyPopup" = false;
  };

  telemetry = {
    "toolkit.telemetry.unified" = false;
    "toolkit.telemetry.enabled" = false;
    "toolkit.telemetry.server" = "data:,";
    "toolkit.telemetry.archive.enabled" = false;
    "toolkit.telemetry.newProfilePing.enabled" = false;
    "toolkit.telemetry.updatePing.enabled" = false;
    "toolkit.telemetry.firstShutdownPing.enabled" = false;
    "toolkit.telemetry.shutdownPingSender.enabled" = false;
    "toolkit.telemetry.bhrPing.enabled" = false;
    "toolkit.telemetry.coverage.opt-out" = true;
    "toolkit.coverage.opt-out" = true;
    "toolkit.coverage.enabled" = false;
    "toolkit.coverage.endpoint.base" = "";
    "datareporting.healthreport.uploadEnabled" = false;
    "datareporting.policy.dataSubmissionEnabled" = false;
    "security.protectionspopup.recordEventTelemetry" = false;
    "browser.newtabpage.activity-stream.feeds.telemetry" = false;
    "browser.newtabpage.activity-stream.telemetry" = false;
    "browser.tabs.crashReporting.sendReport" = false;
    "breakpad.reportURL" = "";
    "dom.private-attribution.submission.enabled" = false; # ad conversion tracking
    # Studies and experiments
    "app.normandy.enabled" = false;
    "app.normandy.api_url" = "";
    "app.shield.optoutstudies.enabled" = false;
    "browser.discovery.enabled" = false;
    # Rollouts let Mozilla change prefs remotely, even with studies off
    "nimbus.rollouts.enabled" = false;
  };

  # The GenerativeAI policy is the main switch. These cover the rest.
  ai = {
    "browser.ai.control.default" = "blocked";
    "browser.ml.enable" = false;
    "browser.ml.chat.enabled" = false;
    "browser.ml.chat.shortcuts" = false; # no "Ask AI" popup on selected text
    "browser.ml.chat.sidebar" = false;
    "browser.ml.linkPreview.enabled" = false;
    "browser.tabs.groups.smart.enabled" = false;
    "browser.search.visualSearch.featureGate" = false;
    "browser.urlbar.quicksuggest.mlEnabled" = false;
    "places.semanticHistory.featureGate" = false;
    "extensions.ml.enabled" = false;
  };

  base =
    privacy
    // location
    // network
    // security
    // media
    // search
    // behavior
    // noise
    // telemetry
    // ai;

  personal = {
    # Resist Fingerprinting forces UTC time, light theme on sites and en-US.
    # Fingerprinting Protection blocks the main tricks without that.
    "privacy.resistFingerprinting" = false; # LW: true
    "privacy.fingerprintingProtection" = true;
    "webgl.disabled" = false; # LW: true, breaks maps and 3D
    # Disk cache is split per site so it can't track me, and pages load faster
    "browser.cache.disk.enable" = true; # LW: false
    "privacy.sanitize.sanitizeOnShutdown" = false; # LW: true, logs me out on every restart
    "browser.toolbars.bookmarks.visibility" = "never"; # LW: always

    # No background connection to Mozilla's push server
    "dom.push.enabled" = false;
    "dom.push.connection.enabled" = false;

    # Memory
    "dom.webgpu.enabled" = false; # still experimental on Linux
    "browser.tabs.unloadOnLowMemory" = true; # off by default on Linux

    # textfox and Sidebery
    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
    "sidebar.revamp" = false; # old sidebar, Sidebery needs it
    "svg.context-properties.content.enabled" = true;
    "widget.gtk.ignore-bogus-leave-notify" = 1;
    "widget.gtk.rounded-bottom-corners.enabled" = false;

    # Hardware decoding for VP8 and VP9 in video calls
    "media.navigator.mediadatadecoder_vpx_enabled" = true;

    # Address bar
    "browser.urlbar.suggest.calculator" = true;
    "browser.urlbar.unitConversion.enabled" = true;
    "browser.urlbar.trimHttps" = true;
    "browser.urlbar.trimURLs" = true;
    "browser.urlbar.suggest.bookmark" = false;
    "browser.urlbar.showSearchTerms.enabled" = false; # always show the URL, not my search words

    # Session and UI
    "browser.startup.page" = 3; # reopen last session
    "browser.sessionstore.restore_pinned_tabs_on_demand" = true;
    "browser.fullscreen.autohide" = false;
    "full-screen-api.transition.timeout" = 0;
    "findbar.modalHighlight" = true;
    "layout.css.prefers-color-scheme.content-override" = 0; # dark theme for sites
    "editor.resizing.enabled_by_default" = true;
    "devtools.chrome.enabled" = true;

    "browser.download.always_ask_before_handling_new_types" = true;
    "network.protocol-handler.external.mailto" = false;
    # For the unsigned rofi tab switcher. Only LibreWolf honors this,
    # Firefox release builds always require signed add-ons.
    "xpinstall.signatures.required" = false;

    # Fonts
    "font.default.x-western" = "sans-serif";
    "font.name.sans-serif.x-western" = "JetBrainsMonoNL Nerd Font Propo";
    "font.name.monospace.x-western" = "JetBrainsMonoNL Nerd Font Propo";
    "font.size.variable.x-western" = 14;
    "font.size.monospace.x-western" = 14;

    # Tapping Alt no longer shows the menu bar
    "ui.key.menuAccessKeyFocuses" = false;
    # Frees Alt+letter (Alt+F, Alt+E...) from opening menus, so they work as my own hotkeys
    "ui.key.menuAccessKey" = 0;
  };
in
{
  settings = base // personal;

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
      updateInterval = 24 * 60 * 60 * 1000; # refresh the icon once a day
      definedAliases = [ "@nw" ];
    };

    "youtube" = {
      urls = [ { template = "https://www.youtube.com/results?search_query={searchTerms}"; } ];
      icon = "https://www.youtube.com/favicon.ico";
      updateInterval = 24 * 60 * 60 * 1000;
      definedAliases = [ "@yt" ];
    };

    "reddit" = {
      urls = [ { template = "https://www.reddit.com/search/?q={searchTerms}"; } ];
      icon = "https://www.reddit.com/favicon.ico";
      updateInterval = 24 * 60 * 60 * 1000;
      definedAliases = [ "@r" ];
    };

    "x" = {
      urls = [ { template = "https://x.com/search?q={searchTerms}&src=typed_query"; } ];
      icon = "https://x.com/favicon.ico";
      updateInterval = 24 * 60 * 60 * 1000;
      definedAliases = [ "@x" ];
    };

    "letterboxd" = {
      urls = [ { template = "https://letterboxd.com/search/films/{searchTerms}/"; } ];
      icon = "https://letterboxd.com/favicon.ico";
      updateInterval = 24 * 60 * 60 * 1000;
      definedAliases = [ "@lb" ];
    };

    "myshows" = {
      urls = [ { template = "https://myshows.me/search/?q={searchTerms}"; } ];
      icon = "https://myshows.me/favicon.ico";
      updateInterval = 24 * 60 * 60 * 1000;
      definedAliases = [ "@ms" ];
    };

    "github" = {
      urls = [ { template = "https://github.com/search?q={searchTerms}&type=repositories"; } ];
      icon = "https://github.com/favicon.ico";
      updateInterval = 24 * 60 * 60 * 1000;
      definedAliases = [ "@gh" ];
    };

    "bing".metaData.hidden = true;
    "amazonnl".metaData.hidden = true;
    "ebay".metaData.hidden = true;
    "google".metaData.alias = "@g";
  };
}
