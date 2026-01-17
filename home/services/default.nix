{ lib, pkgs, config, ... }:

{
  imports = [
    ./dunst.nix
    ./flameshot.nix
    ./redshift.nix
    ./pass-secret-service.nix
  ];
}
