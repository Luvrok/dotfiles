{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

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

  hidden = lib.filter (m: !m.greeter) config.galaxy.host.monitors;
in
{
  options.galaxy.desktop.sddm.enable = lib.mkEnableOption "SDDM with the VoidSDDM theme";

  config = lib.mkIf config.galaxy.desktop.sddm.enable {
    environment.systemPackages = [ voidsddm ];

    services.displayManager.sddm = {
      enable = true;
      wayland.enable = false;
      package = pkgs.kdePackages.sddm;
      theme = "VoidSDDM";
      extraPackages = with pkgs.kdePackages; [ qtsvg ];
      setupScript = lib.mkIf (hidden != [ ]) (
        lib.concatMapStrings (m: "${pkgs.xrandr}/bin/xrandr --output ${m.output} --off\n") hidden
      );
    };
  };
}
