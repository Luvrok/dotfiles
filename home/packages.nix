{ pkgs, ... }:

let
  # jq filters use $vars inside single quotes on purpose (SC2016)
  script =
    name: runtimeInputs:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      excludeShellChecks = [ "SC2016" ];
      text = builtins.readFile ./scripts/${name};
    };
in
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

    # old nixpkgs: xorg.xprop
    (script "i3-sp" [ jq xprop ])
    (script "i3-ws-anim" [ jq xprop ])
    (script "i3-tile" [ i3 jq coreutils ])
    (script "i3-ws" [ i3 jq coreutils ])
  ];
}
