{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.galaxy.host) user;
in
{
  options.galaxy.desktop.greenclip.enable = lib.mkEnableOption "greenclip clipboard history";

  config = lib.mkIf config.galaxy.desktop.greenclip.enable {
    services.greenclip.enable = true;
    systemd.services.greenclip.serviceConfig.User = user;

    environment.systemPackages = [
      (config.galaxy.lib.mkScript pkgs {
        name = "rofi-greenclip";
        src = ./rofi-greenclip;
        runtimeInputs = [ pkgs.rofi ];
      })
    ];

    home-manager.users.${user}.xdg.configFile."greenclip.toml".text = ''
      [greenclip]
      blacklisted_applications = []
      enable_image_support = true
      history_file = "/home/${user}/.cache/greenclip.history"
      image_cache_directory = "/tmp/greenclip"
      max_history_length = 200
      max_selection_size_bytes = 0
      trim_space_from_selection = true
      use_primary_selection_as_input = false
      static_history = [""]
    '';
  };
}
