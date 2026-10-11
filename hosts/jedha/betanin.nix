{ config, lib, pkgs, ... }:

let
  proxy = null;

  betanin = pkgs.python3Packages.buildPythonApplication rec {
    pname = "betanin";
    version = "0.6.3";
    format = "wheel";

    src = pkgs.fetchPypi {
      inherit pname version format;
      dist = "py3";
      python = "py3";
      hash = "sha256-8tLWwYeZYOOmLZH5of6QKR5FGRpW1CKFjebSFnXEXsc=";
    };

    dependencies = with pkgs.python3Packages; [
      alembic
      apprise
      beets
      click
      flask
      flask-cors
      flask-jwt-extended
      flask-migrate
      flask-restx
      flask-socketio
      flask-sqlalchemy
      gevent
      loguru
      ptyprocess
      python-engineio
      python-socketio
      pyxdg
      sqlalchemy
      sqlalchemy-utils
      tomli-w
    ];

    makeWrapperArgs = [
      "--chdir"
      "${placeholder "out"}/${pkgs.python3.sitePackages}"
    ];

    meta.mainProgram = "betanin";
  };
in
{
  sops.secrets.betanin_password = { };
  sops.secrets.betanin_api_key = { };

  sops.templates."betanin-config" = {
    owner = "beets";
    mode = "0600";
    path = "/var/lib/betanin/config.toml";
    restartUnits = [ "betanin.service" ];
    content = ''
      [frontend]
      username = "morturion"
      password = "${config.sops.placeholder.betanin_password}"

      [clients]
      api_key = "${config.sops.placeholder.betanin_api_key}"

      [server]
      num_parallel_jobs = 1

      [notifications.services]

      [notifications.strings]
      title = "[betanin] torrent `$name` $status"
      body = "@ $time. view/use the console at http://127.0.0.1:9393/$console_path"
    '';
  };

  systemd.services.betanin = {
    description = "betanin";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    path = [ pkgs.beets ];

    environment = {
      BEETSDIR = "/var/lib/beets";
      XDG_CONFIG_HOME = "/var/lib";
      XDG_DATA_HOME = "/var/lib";
      BETANIN_HOST = "127.0.0.1";
      BETANIN_PORT = "9393";
    }
    // lib.optionalAttrs (proxy != null) {
      http_proxy = proxy;
      https_proxy = proxy;
      no_proxy = "127.0.0.1,localhost";
    };

    serviceConfig = {
      ExecStart = lib.getExe betanin;
      User = "beets";
      Group = "media";
      UMask = "0002";
      StateDirectory = "betanin";
      StateDirectoryMode = "0700";
      Restart = "on-failure";
      NoNewPrivileges = true;
      PrivateTmp = true;
      ProtectHome = true;
    };
  };
}
