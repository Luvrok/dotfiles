{ pkgs, ... }:
{
  # puts wifi-menu in PATH with its deps
  home.packages = [
    (pkgs.writeShellApplication {
      name = "wifi-menu";
      runtimeInputs = with pkgs; [ iwd systemd jq eww i3 libnotify coreutils ];
      text = builtins.readFile ./scripts/wifi-menu.sh;
    })
  ];
}
