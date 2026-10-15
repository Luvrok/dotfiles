{ pkgs, ... }:

{
  home.packages = with pkgs; [
    # based
    direnv
    kitty
    fish
    fastfetch
    p7zip
    ly
    figlet

    # pass
    pass
    pinentry-curses
    pwgen
    pass-secret-service
    libsecret

    poppler-utils
    dragon-drop

    (pkgs.writeShellApplication {
      name = "i3-monocle";
      runtimeInputs = [
        pkgs.jq
        pkgs.i3
      ];
      text = builtins.readFile ./scripts/i3-monocle;
    })

    (pkgs.writeShellApplication {
      name = "i3-sp";
      runtimeInputs = [ pkgs.jq pkgs.xprop ]; # old nixpkgs: pkgs.xorg.xprop
      # jq filters use $vars inside single quotes on purpose
      excludeShellChecks = [ "SC2016" ];
      text = builtins.readFile ./scripts/i3-sp;
    })

    (pkgs.writeShellApplication {
      name = "i3-ws-anim";
      runtimeInputs = [ pkgs.jq pkgs.xprop ];
      excludeShellChecks = [ "SC2016" ];
      text = builtins.readFile ./scripts/i3-ws-anim;
    })

    (pkgs.writeShellApplication {
      name = "i3-tile";
      runtimeInputs = [ pkgs.i3 pkgs.jq pkgs.coreutils ];
      excludeShellChecks = [ "SC2016" ];
      text = builtins.readFile ./scripts/i3-tile;
    })

    (pkgs.writeShellApplication {
      name = "i3-ws";
      runtimeInputs = [ pkgs.i3 pkgs.jq pkgs.coreutils ];
      excludeShellChecks = [ "SC2016" ];
      text = builtins.readFile ./scripts/i3-ws;
    })
  ];
}
