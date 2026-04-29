{ ... }:

{
  enable = true;
  persistentKeys = true;
  settings = {
    Peers = [
      "tls://45.135.180.21:42853" # my nl server
      "tls://45.38.20.238:42853" # my us server

      # Helsinki
      "tls://95.217.35.92:1337"
      # "quic://ygg-hel-1.wgos.org:45171"

      # Frankfurt
      "tls://103.109.234.106:443?key=000000035621c71b5610434589df051aed2688510f904ae79860668dc0fbf182"
      # "quic://31.57.241.104:65535"

      # Amsterdam
      "tls://vpn.itrus.su:7992"
      # "quic://vpn.itrus.su:7993"
    ];
    IfName = "ygg0";
  };
}
