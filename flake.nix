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
    nixpkgs-hypr.url = "github:nixos/nixpkgs/d4f25a3e562008648d45bcf2d70bcc7422cad84e";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    zapret-discord-youtube.url = "github:kartavkun/zapret-discord-youtube";
    lazygit.url = "github:jesseduffield/lazygit";

    # xray gets its own snapshot: `nix flake update xray`
    xray.url = "github:nixos/nixpkgs/nixos-unstable";

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
      xray,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      # xray is the one package that needs a newer nixpkgs than the system's
      xrayPkgs = import xray {
        inherit system;
        config.allowUnfree = true;
      };

      pkgs = import nixpkgs {
        inherit system;
        config = {
          allowBroken = false;
          allowUnfree = true;
          allowInsecure = false;
        };
        overlays = [
          (
            final: prev:
            let
              craftApps = import ./modules/nixos/desktop/craft-apps.nix { pkgs = prev; };
            in
            {
              # the StoryTold apps come from their upstream AppImages, no
              # rust build and no test suite. versions and hashes live in
              # craft-apps.nix
              inherit (craftApps)
                photocraft
                vectorcraft
                wordcraft
                gridcraft
                pdfcraft
                deckcraft
                soundcraft
                effectcraft
                figcraft
                filmcraft
                ;
              inherit (xrayPkgs) xray;
            }
          )
        ];
      };

      # the compositor and the shell, from their own snapshot (see the input)
      pkgs-hypr = import nixpkgs-hypr {
        inherit system;
        config = {
          allowUnfree = true;
        };
        overlays = [
          # quickshell 0.3.2 drops the level of a mono source: its peak
          # stream is stereo, the node's channels are one, and it treats
          # that as an error. the mic's bar in the audio menu works with it
          (final: prev: {
            quickshell = prev.quickshell.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [ ./modules/nixos/hyprland/quickshell-peak-mono.patch ];
            });
          })
        ];
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
      # bump the storytold AppImages to their latest releases:
      # nix run .#update-craft-apps
      apps.${system}.update-craft-apps = {
        type = "app";
        program = "${
          pkgs.writeShellApplication {
            name = "update-craft-apps";
            runtimeInputs = with pkgs; [
              curl
              jq
              nix
              perl
            ];
            text = builtins.readFile ./modules/nixos/desktop/update-craft-apps.sh;
          }
        }/bin/update-craft-apps";
      };

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
              configName = "general(ALT13)";
            };
          }

          home-manager.nixosModules.home-manager
          (make_hm "barnard")
          (
            { pkgs, ... }:
            {
              # 7.3 corrupts the DCN32 scanout in single frames
              # (a637a140ab86), 7.2 is the last good release
              boot.kernelPackages = pkgs.linuxPackages_7_2;
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
          sops-nix.nixosModules.sops
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
