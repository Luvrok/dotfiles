{ ... }:

{
  services.yggdrasil = {
    enable = true;
    persistentKeys = true;
    settings = {
      Peers = [
        # "tls://vpn.itrus.su:7992"
        # "tls://95.217.35.92:1337"
        "tls://45.38.20.187:42853" # my us server
        "tls://78.17.70.36:42853" # my nl server
      ];
      IfName = "ygg0";
    };
  };
}
