# every host imports this (flake.nix). each module here is off until the
# host turns it on, modules/nixos/desktop adds the desktop's own
{ ... }:

{
  imports = [
    ./doh
    ./doh/local-doh.nix
    ./small-disk.nix
    ./kiss-worker.nix
    ./xray-geodata.nix
  ];
}
