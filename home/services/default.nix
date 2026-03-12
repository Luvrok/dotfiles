{ lib, pkgs, config, ... }:

{
  imports = [
    ./dunst.nix
    ./flameshot.nix
    ./redshift.nix
    ./activitywatch.nix
    ./pass-secret-service.nix
  ];
}
