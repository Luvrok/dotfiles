{
  config,
  pkgs,
  ...
}:

let
  cfg = config.services.xray;

  # the numbers a link is made of. all of them are secrets, so they come
  # from sops at runtime and never reach the store
  params = config.sops.secrets.subscription.path;
in
{
  sops.secrets.subscription = {
    mode = "0400";
  };

  # one file per user, named after a token derived from the pepper. the url
  # never changes, so a new server or a new sni means "update the file",
  # not "send eight people a new config"
  systemd.services.xray-subscription = {
    description = "Render per-user subscription links";
    wantedBy = [ "multi-user.target" ];
    wants = [ "sops-install-secrets.service" ];
    after = [ "sops-install-secrets.service" ];
    path = [
      pkgs.coreutils
      pkgs.jq
    ];
    serviceConfig = {
      Type = "oneshot";
      StateDirectory = "xray-subscription";
      StateDirectoryMode = "0750";
      # nginx reads these files as group nginx
      Group = "nginx";
      UMask = "0027";
    };
    script = ''
      set -euo pipefail

      params=${params}
      conf=${cfg.settingsFile}
      out=/var/lib/xray-subscription
      admin=/var/lib/xray-subscription-admin

      host=$(jq -er .host "$params")
      port=$(jq -er .port "$params")
      sni=$(jq -er .sni "$params")
      pbk=$(jq -er .publicKey "$params")
      sid=$(jq -er .shortId "$params")
      path=$(jq -er .path "$params")
      pepper=$(jq -er .pepper "$params")
      fp=$(jq -r '.fingerprint // "firefox"' "$params")
      mode=$(jq -r '.mode // "auto"' "$params")

      install -d -m 0700 -o root -g root "$admin"
      : > "$admin/index.tsv"

      # a subscription file is meant to be replaced, not merged
      find "$out" -maxdepth 1 -type f -delete

      jq -r '.inbounds[] | select(.tag == "xhttp-in") | .settings.clients[] | [.email, .id] | @tsv' "$conf" |
      while IFS=$'\t' read -r email id; do
        token=$(printf '%s' "$email:$pepper" | sha256sum | cut -c1-32)
        label=$(jq -rn --arg v "$email" '$v|@uri')
        epath=$(jq -rn --arg v "$path" '$v|@uri')

        link="vless://''${id}@''${host}:''${port}?encryption=none&security=reality&sni=''${sni}&fp=''${fp}&pbk=''${pbk}&sid=''${sid}&type=xhttp&path=''${epath}&mode=''${mode}#''${label}"

        # v2rayng, nekoray and streisand all accept the plain list, the
        # base64 copy is there for clients that insist on it
        printf '%s\n' "$link" > "$out/$token.txt"
        printf '%s\n' "$link" | base64 -w0 > "$out/$token"

        printf '%s\t%s\n' "$email" "$token" >> "$admin/index.tsv"
      done

      chmod 0640 "$out"/*
      chmod 0600 "$admin/index.tsv"
    '';
  };

  systemd.timers.xray-subscription = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "15min";
    };
  };
}
