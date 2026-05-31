{ pkgs, ... }:

{
  enable = true;
  package = pkgs.ollama-vulkan;
  host = "0.0.0.0";
  port = 11434;
  environmentVariables = {
    OLLAMA_FLASH_ATTENTION = "1";
    OLLAMA_MAX_LOADED_MODELS = "1";
  };
  loadModels = [
    "gpt-oss:latest"
    "qooba/qwen3-coder-30b-a3b-instruct:q3_k_m"
    "codegemma:latest"
    "qwen2.5-coder:14b"
    "qwen2.5:14b"
  ];
}
