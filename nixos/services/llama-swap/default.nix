{
  pkgs,
  lib,
  config,
  ...
}:

let
  cfg = config.services.llama-swap;
  # nixpkgs' vulkan build, from cache.nixos.org, on every host. on barnard
  # vulkan also sees the ryzen's igpu (it works from system ram) and split
  # the models onto it: llama-bench gemma-26b tg 14 t/s on both, 129 on the
  # rx 7800 xt alone (rocm: 85). so the igpu is hidden from it, below
  nvidia = lib.elem "nvidia" config.services.xserver.videoDrivers;
  llama-cpp = pkgs.llama-cpp-vulkan;
  # qwen runs on rocm (config.yaml, chat-rocm): with its mtp drafts it gave
  # ~36 t/s there, ~25 on vulkan, though vulkan is faster without them
  # (llama-bench tg 34 vs 24 at 10k). the nvidia host has no rocm, the name
  # is its vulkan llama-server there
  llama-server-rocm = pkgs.writeShellScriptBin "llama-server-rocm" ''
    exec ${if nvidia then llama-cpp else pkgs.llama-cpp-rocm}/bin/llama-server "$@"
  '';
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
    # the discrete gpu only, for llama-server and sd-server (both ggml):
    # vulkan and rocm see the igpu too. the nvidia host's order isn't
    # known, it keeps them all
    environment = lib.optionalAttrs (!nvidia) {
      GGML_VK_VISIBLE_DEVICES = "0";
      HIP_VISIBLE_DEVICES = "0";
    };

    path = [
      llama-cpp
      llama-server-rocm
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
