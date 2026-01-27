{
  description = "Luvrok's nixos configuration";

  inputs = {
    nixpkgs-pinned.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    deploy-rs.url = "github:serokell/deploy-rs";
    disko.url = "github:nix-community/disko";

    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    nur.url = "github:nix-community/NUR";
    nur.inputs.nixpkgs.follows = "nixpkgs";

    zapret-discord-youtube.url = "github:kartavkun/zapret-discord-youtube";
    textfox.url = "github:adriankarlen/textfox";

    # my stuff
    dwm.url = "github:Luvrok/dwm";
    dwm.flake = false;
    st.url = "github:Luvrok/st";
    st.flake = false;
    dwmblocks.url = "github:Luvrok/dwmblocks-async";
    dwmblocks.flake = false;

    # zsh plugin manager
    zinit.url = "github:zdharma-continuum/zinit";
    zinit.flake = false;
  };

  outputs = { self, nixpkgs, nixpkgs-pinned, home-manager, deploy-rs, disko, nur, zapret-discord-youtube, dwm, st, dwmblocks, ... }@inputs: let
    system = "x86_64-linux";
    pkgs = import nixpkgs {
      inherit system;
      config = {
        allowBroken = false;
        allowUnfree = true;
        allowInsecure = false;
      };
    };

    make_hm = username: { ... }: {
      home-manager = {
        useGlobalPkgs = true;
        useUserPackages = true;
        backupFileExtension = "backup";
        users.${username} = {
          imports = [ "${self}/home" ];
        };
        extraSpecialArgs = {
          inherit username inputs system;
          pkgs-pinned = import nixpkgs-pinned { inherit system; };
        };
      };
    };
  in {
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
            enable = false;
            config = "general(ALT)";
          };
        }

        home-manager.nixosModules.home-manager
        (make_hm "barnard")
        ({ config, pkgs, ... }: {
          boot.kernelPackages = pkgs.linuxPackages_latest;
        })
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
        ./nixos/hardware/amd.nix
        ./hosts/sun/hardware-configuration.nix
        ./hosts/sun/env.nix

        zapret-discord-youtube.nixosModules.default
        {
          services.zapret-discord-youtube = {
            enable = true;
            config = "general(ALT2)";
          };
        }

        home-manager.nixosModules.home-manager
        (make_hm "dash")
        ({ config, pkgs, ... }: {
          boot.kernelPackages = pkgs.linuxPackages_latest;
        })
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
        xorg.libXcursor
        xorg.libX11
        xorg.libXinerama
        xorg.libXft
        xorg.libxcb
        xorg.xcbutil
        freetype
        fontconfig
        pkg-config
     ];
    };
  };
}
