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
    voidsddm.url = "github:Luvrok/VoidSDDM";
    voidsddm.flake = false;
  };

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      galaxyLib = import ./lib { inherit lib; };

      # Every folder in hosts/ is a machine.
      hosts = lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./hosts));
      machines = lib.genAttrs hosts (name: galaxyLib.mkHost { inherit name inputs self; });
    in
    {
      nixosConfigurations = machines // {
        # alderaan's hostname is still "dash"; `nh os switch` looks it up by hostname.
        dash = machines.alderaan;
      };

      checks.${system} = lib.mapAttrs (_: machine: machine.config.system.build.toplevel) machines;

      formatter.${system} = pkgs.nixfmt-tree;

      overlays.default = import ./pkgs inputs;

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
