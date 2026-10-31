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

    # kodi and its add-ons (nixos/services/kodi), pinned to a commit each:
    # `nix flake update` leaves them, kodi is built with a patch
    # (kodi-keys.patch) and majan with patches that want its exact xml.
    # moving one is changing its rev here, then `nix flake lock`
    nixpkgs-kodi.url = "git+https://github.com/NixOS/nixpkgs?shallow=1&rev=02c087f3fe673c9e317f206a627cb6b910336dbe";
    kodi-skins.url = "git+https://github.com/KarmaMole/kodi-skins?shallow=1&rev=0f6a3246f1aa41e82f895366709d2bcaaa87e6fc";
    kodi-skins.flake = false;
    kodi-skinvariables.url = "git+https://github.com/jurialmunkey/script.skinvariables?ref=nexus&shallow=1&rev=9c20ea9bcf67fcb4370a5771da08b6cf7bdb676e";
    kodi-skinvariables.flake = false;
    kodi-tmdbhelper.url = "git+https://github.com/jurialmunkey/plugin.video.themoviedb.helper?ref=nexus&shallow=1&rev=edae17cb8bfc69d1f614ff44b2490ecd6bd5e9a0";
    kodi-tmdbhelper.flake = false;
    kodi-jurialmunkey.url = "git+https://github.com/jurialmunkey/script.module.jurialmunkey?shallow=1&rev=8f42fb5f4698f3e4552f38955964b2f3843dba69";
    kodi-jurialmunkey.flake = false;
    kodi-infotagger.url = "git+https://github.com/jurialmunkey/script.module.infotagger?shallow=1&rev=0118f53c9cf68a6625794d07af607cac1e920064";
    kodi-infotagger.flake = false;

    # rutracker through cloudflare for prowlarr (nixos/services/arr)
    rutracker-cf-proxy.url = "git+https://github.com/rofl3228/rutracker-cf-proxy?shallow=1";
    rutracker-cf-proxy.flake = false;


    # nixpkgs lags behind, pinned to a commit so `nix flake update` leaves it
    llama-cpp.url = "github:ggml-org/llama.cpp/3bb63cbcbfb62056c84fe9e521b0f3d756d29c32";
    llama-cpp.flake = false;
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
              imports = [ "${self}/home" ];
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
          ./nixos
          ./nixos/hardware/amd.nix
          ./hosts/barnard/hardware-configuration.nix
          ./hosts/barnard/env.nix

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
              # Issue: kernel panic "BUG at mm/vmalloc.c:3167" occurring ~once a week since last year, sometimes more often.
              # Context: AMD + amdgpu with dual-monitor setup (both 120 Hz); may be related (see forum thread).
              # Best solution yet: pin the Linux 6.12 kernel.
              # Ref: https://bbs.archlinux.org/viewtopic.php?id=306587
              boot.kernelPackages = pkgs.linuxPackages_6_12;
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
          ./nixos
          ./nixos/hardware/nvidia.nix
          ./hosts/alderaan/hardware-configuration.nix
          ./hosts/alderaan/env.nix

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
