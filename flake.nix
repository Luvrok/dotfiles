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
    better-swallow.url = "github:afishhh/better-swallow";
    lazygit.url = "github:jesseduffield/lazygit";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    dwm.url = "github:Luvrok/dwm";
    dwm.flake = false;
    st.url = "github:Luvrok/st";
    st.flake = false;
    dwmblocks.url = "github:Luvrok/dwmblocks-async";
    dwmblocks.flake = false;
    dmenu.url = "github:Luvrok/dmenu";
    dmenu.flake = false;
    slock.url = "github:Luvrok/slock";
    slock.flake = false;
    textfoxy.url = "github:Luvrok/textfoxy";
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
              inherit (config) videoDrivers dpi fontSize;
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
              configName = "general(ALT9)";
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
          ./hosts/sun/hardware-configuration.nix
          ./hosts/sun/env.nix

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
          ./hosts/kessel
        ];
      };

      nixosConfigurations."tatooine" = nixpkgs.lib.nixosSystem {
        inherit pkgs;
        specialArgs = {
          username = "tatooine";
        };
        modules = [
          ./hosts/tatooine
        ];
      };

      nixosConfigurations."jedha" = nixpkgs.lib.nixosSystem {
        inherit pkgs;
        specialArgs = {
          username = "jedha";
        };
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./hosts/jedha
        ];
      };

      devShells.${system}.default = pkgs.mkShell {
        buildInputs = with pkgs; [
          stdenv.cc
          gnumake
          libXcursor
          libX11
          libXinerama
          libXft
          libxcb
          xcbutil
          freetype
          fontconfig
          pkg-config
          yajl
          libXres
          imlib2
          libxrandr
          libxcrypt
          libxext
        ];
      };
    };
}
