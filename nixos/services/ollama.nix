{ pkgs, ... }:

{
  enable = true;
  package = pkgs.ollama-vulkan;
  host = "0.0.0.0";
  port = 11434;
  environmentVariables = {
    OLLAMA_FLASH_ATTENTION = "1";
    OLLAMA_MAX_LOADED_MODELS = "1";
    OLLAMA_MAX_VRAM = "0.9";
  };
  loadModels = [
    "gpt-oss:latest"
    "gemma4:e4b"
    "qooba/qwen3-coder-30b-a3b-instruct:q3_k_m"
  ];
}
