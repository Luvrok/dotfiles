{
  description = "Luvrok's nixos configuration";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # the desktop's own snapshot. hyprland and quickshell are pre-1.0 and
    # move fast: a nixpkgs update must not move them. this is the rev the
    # desktop was tested on, not a random commit. a rev never moves, so a
    # plain `nix flake update` leaves it alone: to bump it, put the rev of a
    # newer nixpkgs here, rebuild, test the session, and roll back to the
    # previous generation if it's worse
    nixpkgs-hypr.url = "github:nixos/nixpkgs/1c89083e451e891152365b799595cf7790a43325";

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
      nixpkgs-hypr,
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

      # the compositor and the shell, from their own snapshot (see the input)
      pkgs-hypr = import nixpkgs-hypr {
        inherit system;
        config = {
          allowUnfree = true;
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
            };
          };
        };
    in
    {
      nixosConfigurations.barnard = nixpkgs.lib.nixosSystem {
        inherit pkgs;
        specialArgs = {
          username = "barnard";
          inherit inputs system pkgs-hypr;
        };
        modules = [
          ./modules/nixos
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
          inherit inputs system pkgs-hypr;
        };
        modules = [
          ./modules/nixos
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
          ./modules/nixos
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
          ./modules/nixos
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
          ./modules/nixos
          ./hosts/jedha
        ];
      };
    };
}
