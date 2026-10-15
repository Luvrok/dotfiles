{ pkgs, ... }:

let
  script =
    name: runtimeInputs:
    pkgs.writeShellApplication {
      inherit name runtimeInputs;
      text = builtins.readFile ./scripts/${name}.sh;
    };
in
{
  imports = [
    ./wifi-menu
  ];

  programs.eww = {
    enable = true;
    yuckConfig = builtins.readFile ./eww.yuck;
    scssConfig = builtins.readFile ./eww.scss;
  };

  xdg.configFile."eww/wifi-menu".source = ./wifi-menu/config;

  home.packages = with pkgs; [
    (script "eww-i3-workspaces" [ i3 jq ])
    (script "eww-i3-windows" [ i3 jq ])
    (script "eww-launch" [ xrandr gawk ])

    (script "i3-rec" [ coreutils ])
    (script "i3-xkb" [ xkb-switch procps coreutils ])
    (script "i3-volume" [ wireplumber gawk procps ])
    (script "i3-memory" [ procps gawk ])
    (script "i3-wifi" [ iwd iw iproute2 gawk coreutils ])
    (script "i3-date" [ coreutils ])
  ];
}
