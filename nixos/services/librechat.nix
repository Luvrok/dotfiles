{
  config,
  pkgs,
  lib,
  ...
}:
let
  llamaSwapPort = 11434; # порт твоего llama-swap
in
{
  services.mongodb.package = pkgs.mongodb-ce;

  sops.secrets = {
    "librechat/creds_key" = { };
    "librechat/creds_iv" = { };
    "librechat/jwt_secret" = { };
    "librechat/jwt_refresh_secret" = { };
    "librechat/tavily_api_key" = { };
    "meilisearch/master_key" = { };
  };

  services.meilisearch.masterKeyFile = config.sops.secrets."meilisearch/master_key".path;

  services.librechat = {
    enable = true;
    enableLocalDB = true; # поднимает mongodb, MONGO_URI ставится сам
    meilisearch.enable = true; # поиск по чатам
    openFirewall = false; # наружу через reverse proxy

    credentials = {
      CREDS_KEY = config.sops.secrets."librechat/creds_key".path;
      CREDS_IV = config.sops.secrets."librechat/creds_iv".path;
      JWT_SECRET = config.sops.secrets."librechat/jwt_secret".path;
      JWT_REFRESH_SECRET = config.sops.secrets."librechat/jwt_refresh_secret".path;
      TAVILY_API_KEY = config.sops.secrets."librechat/tavily_api_key".path;
    };

    env = {
      HOST = "127.0.0.1";
      PROXY = "http://127.0.0.1:10808";
      NO_PROXY = "127.0.0.1,localhost";
      PORT = 3080;
      DOMAIN_CLIENT = "https://chat.example.com";
      DOMAIN_SERVER = "https://chat.example.com";
      ALLOW_REGISTRATION = true; # после создания своего аккаунта поставь false
      ALLOW_SOCIAL_LOGIN = false;
      SEARXNG_INSTANCE_URL = "http://127.0.0.1:11433";
    };

    settings = {
      version = "1.2.1";
      cache = true;
      endpoints.custom = [
        {
          name = "llama-swap";
          apiKey = "none"; # пустое значение нельзя, llama-swap ключ не проверяет
          baseURL = "http://127.0.0.1:${toString llamaSwapPort}/v1";
          models = {
            default = [ "qwen" ]; # запасной список на случай, если fetch не сработал
            fetch = true; # берёт модели из /v1/models llama-swap
          };
          titleConvo = true;
          titleModel = "current_model";
          modelDisplayLabel = "llama-swap";
        }
      ];

      webSearch = {
        searchProvider = "searxng";
        searxngInstanceUrl = "\${SEARXNG_INSTANCE_URL}";
        searxngSearchOptions.engines = [
          "google"
          "bing"
          "brave"
          "startpage"
          "qwant"
        ];

        scraperProvider = "tavily";
        tavilyApiKey = "\${TAVILY_API_KEY}";

        rerankerType = "none";
        safeSearch = 0;
        allowedAddresses = [
          "127.0.0.1:11433"
          "127.0.0.1:3002"
        ];
      };
    };
  };

  # reverse proxy, если нужен
  services.caddy.virtualHosts."chat.example.com".extraConfig = ''
    reverse_proxy 127.0.0.1:3080
  '';
}
