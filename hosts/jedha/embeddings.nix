# EmbeddingGemma 2 on llama-server, CPU only. docs-mcp gets its vectors here
{ lib, ... }:
let
  # from unsloth/embeddinggemma-2-GGUF, downloaded by hand.
  # F16 gives NaN on CPU, BF16 has no fast path on this cpu
  quant = "Q8_0";
in
{
  systemd.tmpfiles.rules = [ "d /var/lib/models 0755 root root -" ];

  services.llama-cpp = {
    enable = true;
    settings = {
      host = "127.0.0.1";
      port = 8090;
      model = "/var/lib/models/embeddinggemma-2-${quant}.gguf";
      # docs-mcp keys its index on this name, a new quant means a reindex
      alias = "embeddinggemma-2-${quant}";
      embeddings = true;
      pooling = "mean";
      gpu-layers = 0;
      threads = 4;
      ctx-size = 8192;
      # n_ubatch = min(n_batch, n_ubatch), and a whole input must fit one ubatch
      batch-size = 8192;
      ubatch-size = 8192;
    };
  };

  systemd.services.llama-cpp.serviceConfig = {
    MemoryMax = "1G";
    RestartSec = lib.mkForce 10; # module default is 300
  };
}
