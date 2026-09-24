{
  config,
  lib,
  pkgs,
  ...
}:

let
  inherit (config.galaxy.host) user sshKeys;
  desktop = config.galaxy.users.desktop.enable;
in
{
  options.galaxy.users.desktop.enable = lib.mkEnableOption "desktop groups and zsh for the main user";

  config = lib.mkMerge [
    {
      users.users.${user} = {
        isNormalUser = true;
        extraGroups = [ "wheel" ];
        openssh.authorizedKeys.keys = sshKeys;
      };

      users.users.root.openssh.authorizedKeys.keys = sshKeys;
    }

    (lib.mkIf (!desktop) {
      users.users.${user}.initialPassword = "nopassword";
    })

    (lib.mkIf desktop {
      users.groups = {
        vboxsf = { };
        plugdev = { };
        storage = { };
      };

      users.users.root.shell = pkgs.bash;

      users.users.${user} = {
        shell = pkgs.zsh;
        extraGroups = [
          "i2c" # monitor brightness
          "networkmanager"
          "network"
          "kvm"
          "libvirtd"
          "vboxusers"
          "vboxsf"
          "audio"
          "plugdev"
          "storage"
          "input"
          "render"
          "video"
          "dialout"
        ];
      };

      programs.zsh.enable = true;
    })
  ];
}
