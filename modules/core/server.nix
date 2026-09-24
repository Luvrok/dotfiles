# Headless machines: ssh with keys only, a copy of this repo in /root/nixos-config.
{
  config,
  lib,
  pkgs,
  self,
  ...
}:

{
  options.galaxy.server.enable = lib.mkEnableOption "the headless server base";

  config = lib.mkIf config.galaxy.server.enable {
    services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };

    i18n.defaultLocale = "en_GB.UTF-8";

    environment.systemPackages = with pkgs; [
      vim
      htop
      curl
      wget
      git
      btop
      vnstat
      dig
      git-crypt
      nh
      iperf
      mtr
      busybox
      age
      sops
    ];

    environment.etc."nixos".source = "${self}/hosts/${config.networking.hostName}";
    system.activationScripts.copyConfig.text = ''
      rm -rf /root/nixos-config
      mkdir -p /root
      cp -rT ${self} /root/nixos-config
      chown -R root:root /root/nixos-config
    '';
  };
}
