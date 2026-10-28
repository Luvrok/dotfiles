# the downloads of kodi's library (../kodi), barnard only, its env.nix
# imports this. how it goes, for reading: movie pipe.md. a film or a show
# asked for in kodi (or a web ui) goes radarr / sonarr -> prowlarr's
# trackers -> qbittorrent -> /media/outer-1/movies, series, named so kodi
# finds it on tmdb by its id. bazarr puts russian and english subtitles
# next to it, an english one with no russian becomes russian on jedha
# (./subtitles.py). the web uis, 127.0.0.1 only (./shared.nix):
# qbittorrent :8140, radarr :7878, sonarr :8989, prowlarr :9696, bazarr
# :6767. ./setup.py sets them up through their apis. the logins go in
# secrets/arr.yaml (sops secrets/arr.yaml, then git add), each optional:
#   rutracker_username, rutracker_password          rutracker in prowlarr
#   opensubtitles_username, opensubtitles_password  opensubtitles.com, bazarr
#   libretranslate_key                              the translations
{
  config,
  lib,
  pkgs,
  inputs,
  username,
  ...
}:

let
  s = import ./shared.nix;

  # radarr, sonarr, prowlarr and bazarr through xray's mixed inbound
  # (hosts/barnard/xray.nix), qbittorrent never: prowlarr's servers
  # (tracker definitions, flaresolverr's test) and radarr's and sonarr's
  # are behind cloudflare, the provider stalls it. 127.0.0.1 and the lan go
  # straight. no searches while xray is off
  useProxy = true;
  proxy = {
    host = "127.0.0.1";
    port = 10808;
  };

  secretsFile = ../../../secrets/arr.yaml;
  hasSecrets = builtins.pathExists secretsFile;
  secrets = if hasSecrets then config.sops.secrets.arr.path else null;

  python = pkgs.python3.withPackages (ps: [ ps.pyyaml ]);

  # rutracker answers anything but a browser with cloudflare's "just a
  # moment", prowlarr's own rutracker and its flaresolverr retry included.
  # this proxy gets cloudflare's cookie from flaresolverr and goes to
  # rutracker with it as the same chrome would (curl_cffi), prowlarr reads
  # rutracker from it (its definition, "RuTracker (proxy)", ./setup.py).
  # github.com/rofl3228/rutracker-cf-proxy, nix flake update
  # rutracker-cf-proxy brings new versions
  rutrackerProxy = pkgs.python3Packages.buildPythonApplication {
    pname = "rutracker-proxy";
    version = inputs.rutracker-cf-proxy.shortRev;
    src = inputs.rutracker-cf-proxy;
    pyproject = true;
    build-system = [ pkgs.python3Packages.setuptools ];
    dependencies = with pkgs.python3Packages; [
      aiohttp
      curl-cffi
    ];
  };
  apps = [
    "radarr"
    "sonarr"
    "prowlarr"
    "bazarr"
  ];
  units = map (a: "${a}.service");
  # the services that touch the library run as the user, the files are
  # theirs like the rest of /media/outer-1
  user = {
    user = username;
    group = "users";
  };
  asUser = {
    User = username;
    Group = "users";
  };

  servarr = app: {
    inherit (user) user group;
    settings = {
      server = {
        bindaddress = "127.0.0.1";
        port = s.${app};
      };
      # no login, nothing but this machine reaches it
      auth.method = "External";
    };
    environmentFiles = [ "${s.keys}/${app}.env" ];
  };

  setupConfig = pkgs.writeText "arr-setup.json" (
    builtins.toJSON {
      inherit (s)
        keys
        qbittorrent
        radarr
        sonarr
        prowlarr
        bazarr
        flaresolverr
        ;
      inherit secrets;
      proxy = if useProxy then proxy else null;
      library = {
        radarr = s.movies;
        sonarr = s.series;
      };
    }
  );

  subtitles = pkgs.writeShellScript "arr-subtitles" ''
    exec ${python}/bin/python3 ${./subtitles.py} ${
      pkgs.writeText "arr-subtitles.json" (
        builtins.toJSON {
          inherit (s) queue;
          inherit secrets;
          ffprobe = "${pkgs.ffmpeg-headless}/bin/ffprobe";
          # jedha through jedha-tunnel.nix, then the same from outside
          translators = [
            "http://127.0.0.1:5390/subtitle-translator"
            "https://lt.vxrnt.ru/subtitle-translator"
          ];
        }
      )
    } "$@"
  '';
in
{
  warnings = lib.optional (
    !hasSecrets
  ) "secrets/arr.yaml is missing (or not git added): no rutracker, opensubtitles.com or translations";

  # the whole file, a key that isn't there is just not used
  sops.secrets.arr = lib.mkIf hasSecrets {
    sopsFile = secretsFile;
    format = "yaml";
    key = "";
    owner = username;
    restartUnits = [ "arr-setup.service" ];
  };

  systemd.tmpfiles.settings."10-arr" = {
    ${s.state}.d = user // {
      mode = "0750";
    };
    ${s.keys}.d = user // {
      mode = "0700";
    };
    ${s.queue}.d = user // {
      mode = "0700";
    };
  };

  # an api key per app, made once: radarr, sonarr and prowlarr take theirs
  # from the environment, bazarr from the file, kodi's add-on reads them
  systemd.services.arr-keys = {
    description = "API keys of radarr, sonarr, prowlarr and bazarr";
    wantedBy = [ "multi-user.target" ];
    before = units apps;
    requiredBy = units apps;
    serviceConfig = asUser // {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    script = ''
      for app in ${toString apps}; do
        [ -s ${s.keys}/$app ] ||
          head -c 16 /dev/urandom | od -An -tx1 | tr -d ' \n' > ${s.keys}/$app
        echo "''${app^^}__AUTH__APIKEY=$(cat ${s.keys}/$app)" > ${s.keys}/$app.env
      done
    '';
  };

  # the torrents of radarr and sonarr, not the gui one (packages.nix).
  # serverConfig goes over its settings on every start. a torrent stops
  # seeding at ratio 2 or after 30 days, then radarr or sonarr take it away
  # (the library keeps its hardlinks)
  services.qbittorrent = user // {
    enable = true;
    profileDir = "/var/lib/qbittorrent";
    webuiPort = s.qbittorrent;
    torrentingPort = s.torrenting;
    serverConfig = {
      LegalNotice.Accepted = true;
      BitTorrent.Session = {
        DefaultSavePath = s.downloads;
        # a category (radarr, sonarr) is a folder of downloads
        DisableAutoTMMByDefault = false;
        QueueingSystemEnabled = false;
        GlobalMaxRatio = 2;
        GlobalMaxSeedingMinutes = 43200;
      };
      Preferences.WebUI = {
        Address = "127.0.0.1";
        # no login from this machine
        LocalHostAuth = false;
      };
    };
  };
  # the disk's top may be root's. no disk: started anyway
  systemd.services.qbittorrent.serviceConfig.ExecStartPre = [
    "-+${pkgs.coreutils}/bin/install -d -o ${username} -g users ${s.downloads}"
  ];
  # peers reach it, the web ui stays on 127.0.0.1
  networking.firewall = {
    allowedTCPPorts = [ s.torrenting ];
    allowedUDPPorts = [ s.torrenting ];
  };

  services.radarr = servarr "radarr" // {
    enable = true;
  };
  services.sonarr = servarr "sonarr" // {
    enable = true;
  };
  # nothing of the library, its own user
  services.prowlarr = {
    enable = true;
    inherit (servarr "prowlarr") settings environmentFiles;
  };

  # cloudflare's checks for prowlarr (1337x, uindex) and rutrackerProxy
  services.flaresolverr = {
    enable = true;
    port = s.flaresolverr;
  };
  systemd.services.flaresolverr.environment.HOST = "127.0.0.1";

  # straight from this ip, not through xray: cloudflare's cookie holds for
  # the ip flaresolverr got it from, and flaresolverr goes straight when
  # this asks it. chrome as flaresolverr's chromium
  systemd.services.rutracker-proxy = {
    description = "RuTracker past cloudflare for prowlarr";
    wantedBy = [ "multi-user.target" ];
    wants = [
      "flaresolverr.service"
      "network-online.target"
    ];
    after = [
      "flaresolverr.service"
      "network-online.target"
    ];
    environment = {
      HOST = "127.0.0.1";
      PORT = toString s.rutracker;
      BYPARR_URL = "http://127.0.0.1:${toString s.flaresolverr}/v1";
      IMPERSONATE = "chrome";
      IP_FAMILY = "4";
      CLEARANCE_FILE = "/var/lib/rutracker-proxy/clearance.json";
    };
    serviceConfig = {
      ExecStart = "${rutrackerProxy}/bin/rutracker-proxy";
      DynamicUser = true;
      StateDirectory = "rutracker-proxy";
      Restart = "on-failure";
      RestartSec = 10;
    };
  };
  # its definition in prowlarr's Definitions/Custom, pointed at it
  systemd.services.prowlarr.serviceConfig.ExecStartPre = [
    (pkgs.writeShellScript "prowlarr-rutracker" ''
      ${pkgs.coreutils}/bin/mkdir -p /var/lib/prowlarr/Definitions/Custom
      DEFINITION_DIR=/var/lib/prowlarr/Definitions/Custom \
        PUBLIC_URL=http://127.0.0.1:${toString s.rutracker}/ \
        exec ${rutrackerProxy}/bin/rutracker-proxy install-definition
    '')
  ];

  # the settings that don't need secrets, over its own on every start.
  # languages, providers and logins: ./setup.py
  services.bazarr = user // {
    enable = true;
    settings = {
      general = {
        ip = "127.0.0.1";
        port = s.bazarr;
        use_sonarr = true;
        use_radarr = true;
        # setup.py's russian and english profile for all of them
        serie_default_enabled = true;
        serie_default_profile = 1;
        movie_default_enabled = true;
        movie_default_profile = 1;
        # only files count, the embeddedsubtitles provider takes the
        # tracks inside out next to the video
        use_embedded_subs = false;
        use_postprocessing = true;
        postprocessing_cmd = "${subtitles} add {{episode}} {{subtitles}} {{subtitles_language_code2}}";
      };
      sonarr = {
        ip = "127.0.0.1";
        port = s.sonarr;
        apikey._secret = "${s.keys}/sonarr";
      };
      radarr = {
        ip = "127.0.0.1";
        port = s.radarr;
        apikey._secret = "${s.keys}/radarr";
      };
      auth.apikey._secret = "${s.keys}/bazarr";
      proxy =
        if useProxy then
          {
            type = "http";
            url = proxy.host;
            inherit (proxy) port;
            exclude = [
              "localhost"
              "127.0.0.1"
            ];
          }
        else
          { type = null; };
    };
  };

  # on every boot and every switch that changes it
  systemd.services.arr-setup = rec {
    description = "Settings of radarr, sonarr, prowlarr and bazarr";
    wantedBy = [ "multi-user.target" ];
    wants = units (
      apps
      ++ [
        "arr-keys"
        "qbittorrent"
        "flaresolverr"
      ]
    );
    after = wants;
    serviceConfig = asUser // {
      Type = "oneshot";
      RemainAfterExit = true;
      TimeoutStartSec = "10min";
      ExecStart = "${python}/bin/python3 ${./setup.py} ${setupConfig}";
      # a step that failed (no network, xray off) again in half an hour
      Restart = "on-failure";
      RestartSec = "30min";
    };
  };

  # the queue of english subtitles (./subtitles.py)
  systemd.paths.arr-subtitles = {
    wantedBy = [ "paths.target" ];
    pathConfig.PathExistsGlob = "${s.queue}/*.json";
  };
  systemd.services.arr-subtitles = {
    description = "Russian subtitles from english ones";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    serviceConfig = asUser // {
      ExecStart = "${subtitles} run";
    };
  };
}
