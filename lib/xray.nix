# Xray configs for the reverse tunnel.
#
# Uses VLESS reverse proxy (xray >= 25.x; the old top-level "reverse" block is gone).
# bridge (jedha, behind NAT) dials every portal over VLESS + REALITY and keeps the
# connection open. A portal (VPS) listens with dokodemo-door on each exposed port
# and sends those connections back through the tunnel; the bridge delivers them
# to 127.0.0.1:<port>. The same REALITY inbound also serves personal devices.
#
# Secrets are left as "@secret:<name>@" strings and filled in at service start
# (see modules/services/xray.nix); `secrets` lists the names a config needs.
{ lib }:

let
  secret = name: "@secret:${name}@";
  flow = "xtls-rprx-vision";
in
{
  inherit secret;

  portal =
    {
      listen,
      port,
      dest,
      serverNames,
      users,
      expose,
      exposeListen,
    }:
    {
      secrets = [
        "reality_private_key"
        "short_id"
        "bridge_uuid"
      ]
      ++ map (u: "user_${u}") users;

      config = {
        log.loglevel = "warning";

        inbounds = [
          {
            tag = "vless-in";
            inherit listen port;
            protocol = "vless";
            settings = {
              decryption = "none";
              clients = [
                {
                  id = secret "bridge_uuid";
                  email = "bridge";
                  inherit flow;
                  # Connections from this user become the outbound "tunnel".
                  reverse.tag = "tunnel";
                }
              ]
              ++ map (u: {
                id = secret "user_${u}";
                email = u;
                inherit flow;
              }) users;
            };
            streamSettings = {
              network = "tcp";
              security = "reality";
              realitySettings = {
                inherit dest serverNames;
                privateKey = secret "reality_private_key";
                shortIds = [ (secret "short_id") ];
              };
            };
            sniffing = {
              enabled = true;
              destOverride = [
                "http"
                "tls"
                "quic"
              ];
            };
          }
        ]
        ++ lib.mapAttrsToList (name: e: {
          tag = "expose-${name}";
          listen = exposeListen;
          inherit (e) port;
          protocol = "dokodemo-door";
          settings = {
            address = "127.0.0.1";
            inherit (e) port;
            network = "tcp,udp";
          };
        }) expose;

        outbounds = [
          {
            tag = "direct";
            protocol = "freedom";
          }
          {
            tag = "block";
            protocol = "blackhole";
          }
        ];

        routing.rules = [
          {
            type = "field";
            inboundTag = lib.mapAttrsToList (name: _: "expose-${name}") expose;
            outboundTag = "tunnel";
          }
          {
            type = "field";
            ip = [ "geoip:private" ];
            outboundTag = "block";
          }
        ];
      };
    };

  bridge =
    { portals }:
    {
      secrets = lib.concatMap (name: [
        "bridge_uuid_${name}"
        "short_id_${name}"
      ]) (lib.attrNames portals);

      config = {
        log.loglevel = "warning";

        outbounds = [
          {
            tag = "direct";
            protocol = "freedom";
          }
        ]
        ++ lib.mapAttrsToList (name: p: {
          tag = "to-${name}";
          protocol = "vless";
          # Flat style: required for "reverse". Traffic the portal sends back
          # arrives as the inbound "from-<name>".
          settings = {
            inherit (p) address port;
            id = secret "bridge_uuid_${name}";
            encryption = "none";
            inherit flow;
            reverse.tag = "from-${name}";
          };
          streamSettings = {
            network = "tcp";
            security = "reality";
            realitySettings = {
              inherit (p) serverName publicKey;
              shortId = secret "short_id_${name}";
              fingerprint = "chrome";
            };
          };
        }) portals;

        routing.rules = [
          {
            type = "field";
            inboundTag = lib.mapAttrsToList (name: _: "from-${name}") portals;
            outboundTag = "direct";
          }
        ];
      };
    };
}
