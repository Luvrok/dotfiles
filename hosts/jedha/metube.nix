{ config, lib, pkgs, ... }:

let
  proxy = null;
  inbox = "/var/lib/media/inbox";
  uid = toString config.users.users.metube.uid;

  ytdlOptions = pkgs.writeText "metube-ytdl-options.json" (
    builtins.toJSON (
      {
        postprocessors = [
          {
            key = "Exec";
            when = "after_move";
            exec_cmd = ''curl -fsS -X POST -H "X-API-Key: $BETANIN_API_KEY" --data-urlencode both=%(filepath)q http://127.0.0.1:9393/api/torrents'';
          }
        ];
      }
      // lib.optionalAttrs (proxy != null) { inherit proxy; }
    )
  );
in
{
  users.users.metube = {
    isSystemUser = true;
    uid = 8081;
    group = "media";
  };

  systemd.tmpfiles.rules = [
    "d ${inbox} 2775 metube media -"
    "d /var/lib/metube 0750 metube media -"
  ];

  sops.templates."metube-env".content = ''
    BETANIN_API_KEY=${config.sops.placeholder.betanin_api_key}
  '';

  virtualisation.oci-containers.containers.metube = {
    image = "ghcr.io/alexta69/metube:latest";
    pull = "newer";
    extraOptions = [ "--network=host" ];
    environmentFiles = [ config.sops.templates."metube-env".path ];

    environment = {
      HOST = "127.0.0.1";
      PORT = "8081";
      PUID = uid;
      PGID = uid;
      UMASK = "002";
      CHOWN_DIRS = "false";
      DOWNLOAD_DIR = inbox;
      TEMP_DIR = inbox;
      STATE_DIR = "/var/lib/metube";
      YTDL_OPTIONS_FILE = "/etc/metube/ytdl-options.json";
      DELETE_FILE_ON_TRASHCAN = "ask";
    };

    volumes = [
      "${inbox}:${inbox}"
      "/var/lib/metube:/var/lib/metube"
      "${ytdlOptions}:/etc/metube/ytdl-options.json:ro"
    ];
  };
}
