# nixosSystem for hosts/<name>, with every module from modules/ and profiles/.
{ lib }:

{
  name,
  inputs,
  self,
  system ? "x86_64-linux",
}:

let
  galaxyLib = import ./. { inherit lib; };
in
lib.nixosSystem {
  specialArgs = {
    inherit inputs self;
    pkgs-pinned = import inputs.nixpkgs-pinned {
      inherit system;
      config.allowUnfree = true;
    };
  };

  modules = [
    {
      options.galaxy.lib = lib.mkOption {
        type = lib.types.attrs;
        readOnly = true;
        default = galaxyLib;
        description = "Helpers from lib/.";
      };

      config = {
        networking.hostName = lib.mkDefault name;
        nixpkgs.hostPlatform = system;
      };
    }

    ../hosts/${name}

    inputs.home-manager.nixosModules.home-manager
    inputs.sops-nix.nixosModules.sops
    inputs.disko.nixosModules.disko
  ]
  ++ galaxyLib.listModules ../modules
  ++ galaxyLib.listModules ../profiles;
}
