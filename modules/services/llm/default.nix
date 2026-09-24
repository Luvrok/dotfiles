# Local LLMs on barnard: llama-swap (llama.cpp + stable-diffusion.cpp) on :11434,
# Open WebUI and LibreChat in front of it, pi coding agent for the user (pi.nix,
# a home-manager module).
{ config, lib, ... }:

{
  imports = [
    ./llama-swap
    ./open-webui.nix
    ./librechat.nix
  ];

  options.galaxy.services.llm.enable = lib.mkEnableOption "the local LLM stack";

  config = lib.mkIf config.galaxy.services.llm.enable {
    home-manager.users.${config.galaxy.host.user}.imports = [ ./pi.nix ];
  };
}
