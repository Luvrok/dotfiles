{ config, lib, pkgs, inputs, ... }:

let
  dwm = pkgs.fetchFromGitHub {
    owner = "Luvrok";
    repo = "dwm";
    rev = "854bac39a479bc6f2833c30aa420608aa2e2de5c";
    hash = "sha256-9JzXVQ1kcCg1VdYolvs03L7gTqRx4+0bzCiMJ7e31Fo=";
  };
  st = pkgs.fetchFromGitHub {
    owner = "Luvrok";
    repo = "st";
    rev = "137e80e557b15b475f3a0014637df47bcdcbf71d";
    hash = "sha256-a8xrU/JDREtLi+e2OSL4Z0+0MqjQ9WnPmnQO4YUvcFQ=";
  };
  yazi = pkgs.fetchFromGitHub {
    owner = "sxyazi";
    repo = "yazi";
    rev = "b65a88075a824e4304dca5428ba05de1404fa635";
    hash = "sha256-Er9d/5F34c2Uw+DN/9j+j7TdeWiSxMQlZSgsATC04cM=";
  };

in
{
  imports = [
    ./extraShell.nix
  ];

  nixpkgs.overlays = [
    (final: prev: {
      dwm = prev.dwm.overrideAttrs (old: {
        pname = "dwm";
        version = "854bac39a479bc6f2833c30aa420608aa2e2de5c";
        src = dwm;
      });
    })
    (final: prev: {
      st = prev.st.overrideAttrs (old: {
        pname = "st";
        version = "137e80e557b15b475f3a0014637df47bcdcbf71d";
        src = st;
      });
    })
    (import ./mpv-config.nix)
    inputs.nur.overlays.default
  ];
}
