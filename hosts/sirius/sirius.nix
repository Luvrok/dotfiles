{ modulesPath, lib, pkgs, ... }:

# nix run --no-write-lock-file github:nix-community/nixos-anywhere -- --flake .#sirius root@45.137.99.130
# nixos-rebuild switch --flake .#sirius --target-host root@45.137.99.130 --sudo

{
  system.stateVersion = "25.11";
  imports = [
    (modulesPath + "/profiles/qemu-guest.nix")
  ];

  boot.loader.grub = {
    enable = true;
    efiSupport = true;
    efiInstallAsRemovable = true;
  };

  time.timeZone = "Europe/Moscow";
  i18n.defaultLocale = "en_GB.UTF-8";

  # services.getty.autologinUser = "root";

  networking.hostName = "sirius";
  networking.wireless.enable = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  systemd.network.enable = true;
  systemd.network.wait-online.anyInterface = true;
  services.resolved.enable = true;
  networking.useNetworkd = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 8448 ];
    allowPing = true;
  };

  systemd.network.networks."10-ens18" = {
    matchConfig.Name = "ens18";
    address = [ "45.137.99.130/24" ];
    routes = [ { routeConfig.Gateway = "45.137.99.1"; } ];
    dns = [ "9.9.9.9" ];
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard"
  ];

  users.users.dash = {
    isNormalUser = true;
    extraGroups = ["wheel"];
    initialPassword = "nopassword";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard"
    ];
  };

  environment.etc."nixos".source = ./.;
  system.activationScripts.copyConfig.text = ''
    rm -rf /root/nixos-config
    mkdir -p /root
    cp -rT ${./../..} /root/nixos-config
    chown -R root:root /root/nixos-config
  '';

  services.xray = {
    enable = true;
    settingsFile = ./xray.json;
  };

  systemd.services.xray = {
    serviceConfig = {
      RuntimeDirectory = "xray";
      RuntimeDirectoryMode = "0750";
      ReadWritePaths = [ "/run/xray" ];

      RuntimeMaxSec = "30min";
      Restart = "always";
    };
  };

  environment.systemPackages = with pkgs; [
    vim
    htop
    curl
    wget
    git
    btop
    xray
    vnstat
    dig
    git-crypt
  ];

  services.vnstat.enable = true;
}
