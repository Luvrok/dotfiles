# vps with a ~10 GB disk (kessel, mos-eisley): every switch leaves the last
# system in the store, a few of them and nh can't copy the next one
{ ... }:

{
  # old generations go once a week, the store gets deduplicated as it fills
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };
  nix.settings = {
    auto-optimise-store = true;
    # a build or a copy that runs low frees space itself, before it fails
    min-free = 1024 * 1024 * 1024;
    max-free = 3 * 1024 * 1024 * 1024;
  };

  # whichever loader the host has: 3 entries, older ones can be collected
  boot.loader.grub.configurationLimit = 3;
  boot.loader.systemd-boot.configurationLimit = 3;

  services.journald.extraConfig = "SystemMaxUse=200M";

  # man pages and nixos docs, nobody reads them on a vps
  documentation.enable = false;
}
