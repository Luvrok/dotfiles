{ ... }:

{
  services.yggdrasil = {
    enable = true;
    persistentKeys = true;
    settings = {
      Peers = [
        "tls://45.38.20.238:42853" # us server
        "tls://vpn.itrus.su:7992" # Amsterdam public peer
      ];
      Listen = [
        "tls://0.0.0.0:42853"
      ];
      IfName = "ygg0";
    };
  };
}
