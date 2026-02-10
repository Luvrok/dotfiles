{ config, lib, pkgs, inputs, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    pass = {
      enable = true;
      package = pkgs.rofi-pass;
      stores = [ "$HOME/.password-store" ];
      extraConfig = import ./rofi-pass.nix { inherit lib pkgs config; };
    };
    terminal = "${pkgs.kitty}/bin/kitty";
    extraConfig = {
      kb-accept-entry = "Control+m,Return,KP_Enter";
      kb-remove-to-eol = "";
      kb-row-down = "Down,Control+n,Control+j";
      kb-row-up = "Up,Control+p,Control+k";
    };
  };
}
