{ config, lib, pkgs, pkgs-stable, inputs, username, ... }:

{
  imports = [
    ./overlays
    ./network
    ./services
    ./modules
    ./security.nix
    ./options.nix
    ./boot.nix
    ./env.nix
    ./packages.nix
  ];

  time.timeZone = "Europe/Moscow";

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS = "ru_RU.UTF-8";
      LC_IDENTIFICATION = "ru_RU.UTF-8";
      LC_MEASUREMENT = "ru_RU.UTF-8";
      LC_MONETARY = "ru_RU.UTF-8";
      LC_NAME = "ru_RU.UTF-8";
      LC_NUMERIC = "ru_RU.UTF-8";
      LC_PAPER = "ru_RU.UTF-8";
      LC_TELEPHONE = "ru_RU.UTF-8";
      LC_TIME = "en_US.UTF-8";
    };
  };

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    warn-dirty = false;
  };

  security.sudo.extraConfig = ''
    Defaults lecture = never
    Defaults timestamp_timeout=450
  '';

  programs.nix-ld.enable = true;
  programs.steam.enable = true;
  programs.gamemode.enable = true;
  programs.zsh.enable = true;

  users.groups.libvirt = {};
  users.groups.vboxsf = {};
  users.groups.plugdev = {};
  users.groups.storage = {};

  users.users.${username} = {
    shell = pkgs.zsh;
    isNormalUser = true;
    extraGroups = [
      "i2c" # monitor brightness
      "networkmanager"
      "network"
      "wheel"
      "kvm"
      "libvirt"
      "libvirtd"
      "vboxusers"
      "vboxsf"
      "audio"
      # "openrazer" # taint for kernel, need to be disable for raport
      "plugdev" # ?
      "storage"
      "input"
      "video"
      "dialout" # for microcontrollers
    ];
  };

  users.users.root.shell = pkgs.bash;

  programs.thunar.enable = true;

  programs.throne = {
    enable = true;
    tunMode.enable = true;
  };

  system.stateVersion = "24.11";
}
