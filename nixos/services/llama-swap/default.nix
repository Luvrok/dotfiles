{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.services.llama-swap;
  # nixpkgs' vulkan build, from cache.nixos.org: amd and nvidia alike
  llama-cpp = pkgs.llama-cpp-vulkan;
  # no gpu variant of it in nixpkgs: this one builds here, small
  sd-cpp = pkgs.stable-diffusion-cpp.override { vulkanSupport = true; };

  # kept as yaml for the anchors and macros. checked at build time, the way
  # the upstream module checks its generated config
  configFile =
    pkgs.runCommandLocal "llama-swap-config.yaml" { nativeBuildInputs = [ cfg.package ]; }
      ''
        llama-swap -validate -config ${./config.yaml}
        cp ${./config.yaml} $out
      '';
in
{
  environment.systemPackages = [ sd-cpp ];

  services.llama-swap = {
    enable = true;
    port = 11434;
  };

  systemd.services.llama-swap = {
    path = [
      llama-cpp
      sd-cpp
    ];

    serviceConfig = {
      ExecStart = lib.mkForce (
        lib.escapeShellArgs [
          (lib.getExe cfg.package)
          "--listen=${cfg.listenAddress}:${toString cfg.port}"
          "--config=${configFile}"
        ]
      );

      SupplementaryGroups = [
        "render"
        "video"
      ];

      MemoryDenyWriteExecute = lib.mkForce false;
      MemorySwapMax = "0";
    };
  };
}
