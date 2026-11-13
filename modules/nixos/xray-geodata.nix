# xray ships no geosite.dat/geoip.dat, so `geosite:category-ru` and
# `geoip:ru` rules are silently ignored without these. the directory is
# handed to xray through XRAY_LOCATION_ASSET
{
  config,
  lib,
  pkgs,
  ...
}:

let
  assets = pkgs.runCommand "xray-geodata" { } ''
    mkdir -p $out
    ln -s ${pkgs.v2ray-geoip}/share/v2ray/geoip.dat $out/geoip.dat
    ln -s ${pkgs.v2ray-domain-list-community}/share/v2ray/geosite.dat $out/geosite.dat
  '';
in
{
  config = lib.mkIf config.services.xray.enable {
    systemd.services.xray.serviceConfig.Environment = [ "XRAY_LOCATION_ASSET=${assets}" ];
  };
}
