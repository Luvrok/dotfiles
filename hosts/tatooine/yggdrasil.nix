{ ... }:

{
  services.yggdrasil = {
    enable = true;
    persistentKeys = true;
    settings = {
      Peers = [
        "tls://45.135.180.21:42853" # nl server
        "tls://leo.node.3dt.net:9003" # Liberty Lake public peer
      ];
      Listen = [
        "tls://0.0.0.0:42853"
      ];
      IfName = "ygg0";
    };
  };
}
