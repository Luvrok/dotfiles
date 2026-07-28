{ pkgs, inputs, ... }:
let
  variant = "gruvbox";

  voidsddm = pkgs.runCommandLocal "void-sddm-${variant}" { } ''
    d=$out/share/sddm/themes/VoidSDDM
    mkdir -p $d
    cp -r ${inputs.voidsddm}/* $d/
    chmod -R u+w $d
    substituteInPlace $d/metadata.desktop \
      --replace 'ConfigFile=configs/default.conf' 'ConfigFile=configs/${variant}.conf'
  '';
in
{
  environment.systemPackages = [ voidsddm ];

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = false;
    package = pkgs.kdePackages.sddm;
    theme = "VoidSDDM";
    extraPackages = with pkgs.kdePackages; [ qtsvg ];
  };
}
