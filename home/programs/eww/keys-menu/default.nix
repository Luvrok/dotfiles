{ pkgs, ... }:
{
  # puts keys-menu in PATH with its deps
  home.packages = [
    (pkgs.writeShellApplication {
      name = "keys-menu";
      runtimeInputs = with pkgs; [ i3 jq eww coreutils gawk xinput xmodmap ];
      # jq and awk programs use $vars inside single quotes on purpose
      excludeShellChecks = [ "SC2016" ];
      text = builtins.readFile ./scripts/keys-menu.sh;
    })
  ];
}
