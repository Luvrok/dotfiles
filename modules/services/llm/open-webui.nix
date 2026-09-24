{ config, lib, ... }:

{
  config = lib.mkIf config.galaxy.services.llm.enable {
    services.open-webui = {
      enable = true;
      port = 11829;

      environment = {
        # env всегда главнее базы
        ENABLE_PERSISTENT_CONFIG = "False";

        # --- подключение к llama-swap ---
        ENABLE_OLLAMA_API = "False";
        ENABLE_OPENAI_API = "True";
        OPENAI_API_BASE_URL = "http://localhost:11434/v1";
        OPENAI_API_KEY = "none";

        # --- без трекинга и внешних запросов ---
        SCARF_NO_ANALYTICS = "True";
        DO_NOT_TRACK = "True";
        ANONYMIZED_TELEMETRY = "False";
        ENABLE_VERSION_UPDATE_CHECK = "False";
        ENABLE_COMMUNITY_SHARING = "False";
        ENABLE_EVALUATION_ARENA_MODELS = "False";
        OFFLINE_MODE = "True"; # никаких обращений к HF/GitHub (см. ниже)

        # --- без пользователей ---
        WEBUI_AUTH = "False";

        # --- картинки ---
        ENABLE_IMAGE_GENERATION = "True";
        IMAGE_GENERATION_ENGINE = "openai";
        IMAGES_OPENAI_API_BASE_URL = "http://localhost:11434/v1";
        IMAGES_OPENAI_API_KEY = "none";
        IMAGE_GENERATION_MODEL = "z-image";
        IMAGE_SIZE = "1024x1024";

        # --- websearch ---
        ENABLE_WEB_SEARCH = "True";
        WEB_SEARCH_ENGINE = "searxng";
        SEARXNG_QUERY_URL = "http://127.0.0.1:11433/search?q=<query>";
        WEB_SEARCH_RESULT_COUNT = "5";
        WEB_SEARCH_CONCURRENT_REQUESTS = "5";
        BYPASS_WEB_SEARCH_EMBEDDING_AND_RETRIEVAL = "False";
        RAG_EMBEDDING_ENGINE = "openai";
        RAG_OPENAI_API_BASE_URL = "http://localhost:11434/v1";
        RAG_OPENAI_API_KEY = "none";
        RAG_EMBEDDING_MODEL = "embed";
        RAG_TOP_K = "5";
        CHUNK_SIZE = "1000";
        CHUNK_OVERLAP = "100";
      };
    };
  };
}
