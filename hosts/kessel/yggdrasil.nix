{ ... }:

{
  services.yggdrasil = {
    enable = true;
    persistentKeys = true;
    settings = {
      Peers = [
        # "tls://vpn.itrus.su:7992" # Amsterdam public peer
        # "tls://95.217.35.92:1337"
        "tls://78.17.70.36:42853" # my nl server
      ];
      Listen = [
        "tls://0.0.0.0:42853"
      ];
      IfName = "ygg0";
    };
  };
}
