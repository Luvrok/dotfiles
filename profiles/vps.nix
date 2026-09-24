# Rented VPS: xray and nothing else.
{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.galaxy.profiles.vps.enable = lib.mkEnableOption "the VPS profile";

  config = lib.mkIf config.galaxy.profiles.vps.enable {
    galaxy = {
      server.enable = lib.mkDefault true;
      services.xray.enable = lib.mkDefault true;
      sops.useHostKey = lib.mkDefault true;

      host.sshKeys = lib.mkDefault [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard"
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGifq/+thCOHb5sXkWRQl9RXtddSAemKErUkdngEa7sJ dash@dash"
      ];

      network = {
        tcpPorts = lib.mkDefault [
          22
          80
          443
          4533
          4545
          8129
          8130
          8208
          8443
          8448
          21027
          22000
          22067
          22070
          42853
        ];
        udpPorts = lib.mkDefault [
          8443
          22000
          22067
          22070
          42853
        ];
      };
    };

    # https://popov.wtf/how-to-prioritize-ipv4-over-ipv6-in-linux
    environment.etc."gai.conf".text = ''
      precedence ::ffff:0:0/96  100
    '';

    environment.systemPackages = [ pkgs.jq ];
  };
}
