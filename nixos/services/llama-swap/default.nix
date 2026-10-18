{
  pkgs,
  lib,
  config,
  ...
}:

let
  sd-cpp = pkgs.stable-diffusion-cpp.override { vulkanSupport = true; };
in
{
  environment.systemPackages = [ sd-cpp ];
  environment.etc."llama-swap/config.yaml".source = ./config.yaml;

  services.llama-swap = {
    enable = true;
    port = 11434;
  };

  systemd.services.llama-swap = {
    path = [
      pkgs.llama-cpp
      sd-cpp
    ];

    restartTriggers = [ config.environment.etc."llama-swap/config.yaml".source ];

    serviceConfig = {
      ExecStart = lib.mkForce (
        lib.escapeShellArgs [
          (lib.getExe config.services.llama-swap.package)
          "--listen=${config.services.llama-swap.listenAddress}:${toString config.services.llama-swap.port}"
          "--config=/etc/llama-swap/config.yaml"
        ]
      );

      SupplementaryGroups = [
        "render"
        "video"
      ];

      PrivateDevices = lib.mkForce false;
      MemoryDenyWriteExecute = lib.mkForce false;
      MemorySwapMax = "0";
    };
  };
}
