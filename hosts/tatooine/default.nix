{ pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./network.nix
    ./yggdrasil.nix
  ];

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    warn-dirty = false;
  };

  time.timeZone = "America/Los_Angeles";
  i18n.defaultLocale = "en_GB.UTF-8";

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard"
  ];

  users.users.tatooine = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    initialPassword = "nopassword";
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKfVMnRoTEwUBqxcm6tzRTiFGZVafQ6dHr95HDM//Wk+ barnard"
    ];
  };

  # https://popov.wtf/how-to-prioritize-ipv4-over-ipv6-in-linux
  environment.etc."gai.conf".text = ''
    precedence ::ffff:0:0/96  100
  '';

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
    nh
    iperf
    mtr
    openssl
    whois
    jq
    busybox
    age
    sops
  ];

  services.vnstat.enable = true;
  system.stateVersion = "25.11";
}
