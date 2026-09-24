{
  config,
  lib,
  pkgs,
  ...
}:

let
  llama-cpp =
    (pkgs.llama-cpp.override {
      rocmSupport = true;
      vulkanSupport = true;
      # Enable BLAS for optimized CPU layer performance (OpenBLAS)
      blasSupport = true;
    }).overrideAttrs
      (oldAttrs: {
        # Enable native CPU optimizations (AVX, AVX2, etc.)
        cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [ "-DGGML_NATIVE=ON" ];
        # Disable Nix's march=native stripping
        preConfigure = ''
          export NIX_ENFORCE_NO_NATIVE=0
          ${oldAttrs.preConfigure or ""}
        '';
      });

  sd-cpp = pkgs.stable-diffusion-cpp.override { vulkanSupport = true; };
in
{
  config = lib.mkIf config.galaxy.services.llm.enable {
    services.llama-swap = {
      enable = true;
      port = 11434;
      # listenAddress defaults to localhost; set "0.0.0.0" + open firewall for LAN access
    };

    environment.etc."llama-swap/config.yaml".source = ./config.yaml;

    systemd.services.llama-swap = {
      # llama-swap starts `llama-server` from cmd, so it must be in PATH
      path = [
        llama-cpp
        sd-cpp
      ];

      # Restart the service when the config changes on rebuild
      restartTriggers = [ config.environment.etc."llama-swap/config.yaml".source ];

      serviceConfig = {
        ExecStart = lib.mkForce (
          lib.escapeShellArgs [
            (lib.getExe config.services.llama-swap.package)
            "--listen=${config.services.llama-swap.listenAddress}:${toString config.services.llama-swap.port}"
            "--config=/etc/llama-swap/config.yaml"
          ]
        );

        # GPU access for the sandboxed service user
        SupplementaryGroups = [
          "render"
          "video"
        ];
        PrivateDevices = lib.mkForce false;

        # llama.cpp JIT-compiles GPU kernels, fails with this on
        MemoryDenyWriteExecute = lib.mkForce false;

        # Model in swap = unusable speed
        MemorySwapMax = "0";
      };
    };

    home-manager.users.${config.galaxy.host.user}.programs.zsh.shellAliases.llm-off =
      "curl -s localhost:${toString config.services.llama-swap.port}/unload";
  };
}
