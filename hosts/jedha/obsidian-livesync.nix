{ username, config, ... }:

let
  cfg = config.services.couchdb;
in
{
  # admin password stays out of the store; couchdb hashes it on first start
  # and writes the hash into local.ini, which is read last and wins.
  # after changing the secret drop [admins] from /var/lib/couchdb/local.ini
  sops.secrets.couchdb_admin_password = { };

  sops.templates."couchdb-admin.ini" = {
    owner = cfg.user;
    group = cfg.group;
    restartUnits = [ "couchdb.service" ];
    content = ''
      [admins]
      ${cfg.adminUser} = ${config.sops.placeholder.couchdb_admin_password}
    '';
  };

  services.couchdb = {
    enable = true;
    adminUser = username;
    bindAddress = "127.0.0.1";
    port = 5984;
    extraConfigFiles = [ config.sops.templates."couchdb-admin.ini".path ];

    # https://github.com/vrtmrz/obsidian-livesync/blob/main/docs/setup_own_server.md#configure
    extraConfig = {
      couchdb = {
        single_node = true;
        max_document_size = 50000000;
      };

      chttpd = {
        require_valid_user = true;
        max_http_request_size = 4294967296;
        enable_cors = true;
      };

      chttpd_auth = {
        require_valid_user = true;
        authentication_redirect = "/_utils/session.html";
      };

      httpd = {
        WWW-Authenticate = ''Basic realm="couchdb"'';
        enable_cors = true;
      };

      cors = {
        origins = "app://obsidian.md,capacitor://localhost,http://localhost";
        credentials = true;
        headers = "accept, authorization, content-type, origin, referer";
        methods = "GET,PUT,POST,HEAD,DELETE";
        max_age = 3600;
      };
    };
  };
}
