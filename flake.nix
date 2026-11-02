{
  description = "Luvrok's nixos configuration";

  inputs = {
    nixpkgs-pinned.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    zapret-discord-youtube.url = "github:kartavkun/zapret-discord-youtube";
    lazygit.url = "github:jesseduffield/lazygit";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    textfoxy.url = "github:Luvrok/textfoxy";
    voidsddm.url = "github:Luvrok/VoidSDDM";
    voidsddm.flake = false;

    # kodi, its library and the downloads for it: services.kodi
    # (Luvrok/kodi). kodi's own nixpkgs and add-ons are pinned there, no
    # follows: kodi builds from source with a patch, its pin keeps that rare
    kodi.url = "git+https://github.com/Luvrok/kodi?shallow=1";

    # the voice assistant, services.jarvis (Luvrok/jarvis). its menu and
    # bar icon are in modules/nixos/hyprland/quickshell
    jarvis.url = "git+https://github.com/Luvrok/jarvis?shallow=1";
    jarvis.inputs.nixpkgs.follows = "nixpkgs";

  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-pinned,
      home-manager,
      disko,
      sops-nix,
      zapret-discord-youtube,
      ...
    }@inputs:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowBroken = false;
          allowUnfree = true;
          allowInsecure = false;
        };
      };

      make_hm =
        username:
        { config, ... }:
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "backup";
            users.${username} = {
              imports = [ "${self}/modules/home" ];
            };
            extraSpecialArgs = {
              inherit username inputs system;
              inherit (config) videoDrivers fontSize;
              pkgs-pinned = import nixpkgs-pinned { inherit system; };
            };
          };
        };
    in
    {
      nixosConfigurations.barnard = nixpkgs.lib.nixosSystem {
        inherit pkgs;
        specialArgs = {
          username = "barnard";
          pkgs-pinned = import nixpkgs-pinned {
            inherit system;
            config = {
              allowUnfree = true;
            };
          };
          inherit inputs system;
        };
        modules = [
          ./modules/nixos/desktop
          ./modules/nixos/hardware/amd.nix
          ./hosts/barnard/hardware-configuration.nix
          ./hosts/barnard

          sops-nix.nixosModules.sops

          zapret-discord-youtube.nixosModules.withTestTools
          {
            services.zapret-discord-youtube = {
              enable = true;
              configName = "general(ALT)";
            };
          }

          home-manager.nixosModules.home-manager
          (make_hm "barnard")
          (
            { pkgs, ... }:
            {
              boot.kernelPackages = pkgs.linuxPackages_latest;
            }
          )
        ];
      };

      nixosConfigurations.dash = nixpkgs.lib.nixosSystem {
        inherit pkgs;
        specialArgs = {
          username = "dash";
          pkgs-pinned = import nixpkgs-pinned {
            inherit system;
            config = {
              allowUnfree = true;
            };
          };
          inherit inputs system;
        };
        modules = [
          ./modules/nixos/desktop
          ./modules/nixos/hardware/nvidia.nix
          ./hosts/dash/hardware-configuration.nix
          ./hosts/dash

          zapret-discord-youtube.nixosModules.default
          {
            services.zapret-discord-youtube = {
              enable = true;
              configName = "general(ALT)";
            };
          }

          home-manager.nixosModules.home-manager
          (make_hm "dash")
          (
            { pkgs, ... }:
            {
              boot.kernelPackages = pkgs.linuxPackages_6_12;
            }
          )
        ];
      };

      nixosConfigurations."kessel" = nixpkgs.lib.nixosSystem {
        inherit pkgs;
        specialArgs = {
          username = "kessel";
        };
        modules = [
          disko.nixosModules.disko
          ./hosts/kessel
          ./hosts/kessel/disk-config.nix
        ];
      };

      nixosConfigurations."mos-eisley" = nixpkgs.lib.nixosSystem {
        inherit pkgs;
        specialArgs = {
          username = "mos-eisley";
        };
        modules = [
          sops-nix.nixosModules.sops
          disko.nixosModules.disko
          ./hosts/mos-eisley
          ./hosts/mos-eisley/disk-config.nix
        ];
      };

      nixosConfigurations."jedha" = nixpkgs.lib.nixosSystem {
        inherit pkgs;
        specialArgs = {
          username = "jedha";
          inherit inputs;
        };
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          zapret-discord-youtube.nixosModules.withTestTools
          {
            services.zapret-discord-youtube = {
              enable = true;
              configName = "general(ALT)";
            };
          }
          ./hosts/jedha
        ];
      };
    };
}
