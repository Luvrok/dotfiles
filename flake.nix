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

    # apps that must move without touching the system nixpkgs: update with
    # `nix flake update apps`. only the packages listed in the overlay below
    # are taken from this snapshot
    apps.url = "github:nixos/nixpkgs/nixos-unstable";

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
      apps,
      xray,
      ...
    }@inputs:
    let
      system = "x86_64-linux";

      # snapshots for the packages that have to update on their own, see the
      # inputs. everything else comes from the main nixpkgs
      appsPkgs = import apps {
        inherit system;
        config.allowUnfree = true;
      };
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
          (final: prev: {
            # desktop apps: install them, don't run their test suites. the
            # checks compile every integration test in release mode and take
            # tens of minutes; they don't affect the installed binaries
            photocraft = appsPkgs.photocraft.overrideAttrs (_: {
              doCheck = false;
            });
            vectorcraft = appsPkgs.vectorcraft.overrideAttrs (_: {
              doCheck = false;
            });
            wordcraft = appsPkgs.wordcraft.overrideAttrs (_: {
              doCheck = false;
            });
            gridcraft = appsPkgs.gridcraft.overrideAttrs (_: {
              doCheck = false;
            });
            deckcraft = appsPkgs.deckcraft.overrideAttrs (_: {
              doCheck = false;
            });
            # this nixpkgs' cargo hook exports AWS_LC_SYS_USE_SYSTEM, so
            # aws-lc-sys needs the system aws-lc in the build inputs
            pdfcraft = appsPkgs.pdfcraft.overrideAttrs (old: {
              doCheck = false;
              buildInputs = (old.buildInputs or [ ]) ++ [ appsPkgs.aws-lc ];
            });
            inherit (xrayPkgs) xray;
          })
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
