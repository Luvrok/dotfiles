{ ... }:

{
  enable = true;
  persistentKeys = true;
  settings = {
    Peers = [
      "tls://78.17.70.36:42853" # my nl server
    ];
    IfName = "ygg0";
  };
}
