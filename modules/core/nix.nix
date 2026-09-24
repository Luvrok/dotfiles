{ inputs, ... }:

{
  nix = {
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      warn-dirty = false;
    };
  };

  nixpkgs = {
    config.allowUnfree = true;
    overlays = [
      (import ../../pkgs inputs)
      inputs.better-swallow.overlay
      inputs.lazygit.overlays.default
    ];
  };
}
