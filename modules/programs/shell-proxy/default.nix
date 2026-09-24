# Local proxy tooling. v2rayN/throne listen on 127.0.0.1:10808;
# `source shell-proxy` points the current shell at it.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.galaxy.programs.shell-proxy.enable = lib.mkEnableOption "the local proxy tools";

  config = lib.mkIf config.galaxy.programs.shell-proxy.enable {
    environment.systemPackages = [
      (config.galaxy.lib.mkScript pkgs {
        name = "shell-proxy";
        src = ./shell-proxy;
      })
    ];

    programs.throne = {
      enable = true;
      tunMode.enable = true;
    };

    environment.etc."proxychains.conf".text = ''
      strict_chain
      proxy_dns
      [ProxyList]
      socks5 127.0.0.1 10808
    '';

    home-manager.users.${config.galaxy.host.user}.home.file = {
      ".local/share/v2rayN/bin/xray/xray".source = "${pkgs.xray}/bin/xray";
      ".local/share/v2rayN/bin/sing_box/sing-box".source = "${pkgs.sing-box}/bin/sing-box";
    };
  };
}
