{ ... }:

{
  services.yggdrasil = {
    enable = true;
    persistentKeys = true;
    settings = {
      Peers = [
        "tls://45.135.180.21:42853" # my nl server
        "tls://45.38.20.238:42853" # my us server
        "tls://95.217.35.92:1337" # Helsinki public peer
      ];
      IfName = "ygg0";
    };
  };
}
