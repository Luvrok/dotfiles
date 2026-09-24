{ config, lib, ... }:

{
  options.galaxy.desktop.redshift.enable = lib.mkEnableOption "redshift";

  config = lib.mkIf config.galaxy.desktop.redshift.enable {
    home-manager.users.${config.galaxy.host.user} = {
      services.redshift = {
        enable = true;
        settings.redshift = {
          brightness-day = "1";
          brightness-night = "1";
          location-provider = "manual";
          adjustment-method = "vidmode";
          transition = "1";
        };
        temperature = {
          day = 5000;
          night = 4000;
        };
        latitude = "59.9343";
        longitude = "30.3351";
      };
    };
  };
}
