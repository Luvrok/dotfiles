{ ... }:

{
  imports = [
    ../fonts.nix
    ../qmk
    ../virtualisation.nix
    ../udevil.nix
    ../xdg
    ../qt
    ../gtk
    # off until the host turns them on
    ../hyprland
    ../docs-mcp
    ../omniroute
    ../notes-mcp
    ../opencode-keys.nix
  ];
}
