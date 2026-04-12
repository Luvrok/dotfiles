{
  description = "Luvrok's nixos configuration";

  inputs = {
    nixpkgs-pinned.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";
    zapret-discord-youtube.url = "github:kartavkun/zapret-discord-youtube";
    better-swallow.url = "github:afishhh/better-swallow";

    dwm.url = "github:Luvrok/dwm";
    dwm.flake = false;
    st.url = "github:Luvrok/st";
    st.flake = false;
    dwmblocks.url = "github:Luvrok/dwmblocks-async";
    dwmblocks.flake = false;
    dmenu.url = "github:Luvrok/dmenu";
    dmenu.flake = false;
    textfoxy.url = "github:Luvrok/textfoxy";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-pinned,
      home-manager,
      disko,
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

          zapret-discord-youtube.nixosModules.default
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

      nixosConfigurations."sirius" = nixpkgs.lib.nixosSystem {
        inherit pkgs;
        specialArgs = {
          username = "sirius";
        };
        modules = [
          disko.nixosModules.disko
          ./hosts/sirius/sirius.nix
          ./hosts/sirius/disk-config.nix
        ];
      };

      nixosConfigurations."sirius-b" = nixpkgs.lib.nixosSystem {
        inherit pkgs;
        specialArgs = {
          username = "sirius";
        };
        modules = [
          disko.nixosModules.disko
          ./hosts/sirius-b/sirius.nix
          ./hosts/sirius/disk-config.nix
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
        ];
      };
    };
}
