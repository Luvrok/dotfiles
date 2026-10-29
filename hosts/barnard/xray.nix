{ lib, username, ... }:

# the vpn without v2rayN: xray as a system service with its mixed (socks5 and
# http) inbound on 127.0.0.1:10808, the port v2rayN used, so the run menu's
# xray mode and shell-proxy keep working. it starts with the system and
# stays up, the switches menu (tools v) stops and starts it until the next
# boot. xray.json is git-crypted like the other hosts' (.gitattributes), the
# service is off while it's missing
let
  hasConfig = builtins.pathExists ./xray-v.json;
in
{
  warnings = lib.optional (
    !hasConfig
  ) "hosts/barnard/xray-v.json is missing (or not git added), xray is off";

  services.xray = lib.mkIf hasConfig {
    enable = true;
    settingsFile = ./xray-v.json;
  };

  systemd.services.xray = lib.mkIf hasConfig {
    # xray doesn't need the network to start, it dials per connection. after
    # network-online so the first ones don't fail, a crash comes back in 10 s
    # forever. a stop from the menu stays stopped
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    startLimitIntervalSec = 0;
    serviceConfig = {
      Restart = "always";
      RestartSec = 10;
    };
  };

  # the switch starts and stops it without a password, like v2rayN did
  security.polkit.extraConfig = lib.mkIf hasConfig ''
    polkit.addRule(function (action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "xray.service" &&
          subject.user == "${username}") {
        var verb = action.lookup("verb");
        if (verb == "start" || verb == "stop" || verb == "restart")
          return polkit.Result.YES;
      }
    });
  '';
}
