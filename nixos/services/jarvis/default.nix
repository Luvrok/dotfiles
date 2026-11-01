# jarvis: a local voice assistant. the go daemon listens (wake word, vad
# and whisper on the cpu), gemma 4 12b in llama-swap answers as the active
# character, qwen3-tts in llama-swap speaks it in that character's voice.
# the menu is quickshell's menus/Jarvis.qml. off by default, a host turns
# it on with services.jarvis.enable once models.lock.json is filled
# (./update-models). off means nothing here: no unit, no config, no models
{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.services.jarvis;
  # xray's mixed inbound (hosts/barnard/xray.nix), the same as docs-mcp's:
  # the hub's lfs cdn and docker hub are cut off without it
  proxy = if config.services.xray.enable then "http://127.0.0.1:10808" else null;
  models = import ./models.nix { inherit pkgs lib proxy; };
  refs = import ./refs.nix { inherit pkgs lib models; };
  quickshell = ../hyprland/quickshell;
  podman = lib.getExe config.virtualisation.podman.package;
  modelsDir = "/var/lib/models/jarvis";

  jarvis = pkgs.buildGoModule {
    pname = "jarvis";
    version = "0.1";
    src = ./daemon;
    vendorHash = "sha256-nqwWB7qzj522G0OKHsuZTCgPbJV3kr+3xwqyZcTdN08=";
    subPackages = [ "cmd/jarvis" ];
    env.CGO_ENABLED = 1;
    buildInputs = [ pkgs.sherpa-onnx ];
    nativeBuildInputs = [ pkgs.patchelf ];
    # miniaudio opens libpulse at runtime, by name
    postFixup = ''
      patchelf --add-rpath ${lib.getLib pkgs.libpulseaudio}/lib $out/bin/jarvis
    '';
    meta.mainProgram = "jarvis";
  };

  characterDirs = lib.attrNames (
    lib.filterAttrs (_: t: t == "directory") (builtins.readDir ./characters)
  );
  characterOf = id: builtins.fromTOML (builtins.readFile (./characters + "/${id}/character.toml"));
  cloned = lib.filter (id: (characterOf id).voice.speaker or "" == "") characterDirs;

  # the characters, each with wake.txt: its wake phrase in the kws model's
  # bpe tokens, "▁HE Y ▁J AR VI S @HEY_JARVIS"
  characters =
    pkgs.runCommandLocal "jarvis-characters"
      { nativeBuildInputs = [ (pkgs.python3.withPackages (p: [ p.sentencepiece ])) ]; }
      ''
        cp -r ${./characters} $out
        chmod -R u+w $out
        python3 - $out ${models.kws}/bpe.model <<'EOF'
        import pathlib, sys, tomllib
        import sentencepiece as spm
        sp = spm.SentencePieceProcessor(model_file=sys.argv[2])
        for d in sorted(pathlib.Path(sys.argv[1]).iterdir()):
            wake = tomllib.loads((d / "character.toml").read_text()).get("wake", "").strip().upper()
            if wake:
                tokens = " ".join(sp.encode(wake, out_type=str))
                (d / "wake.txt").write_text(f"{tokens} @{wake.replace(' ', '_')}\n")
        EOF
      '';

  configFile = (pkgs.formats.toml { }).generate "jarvis.toml" {
    llm = {
      url = cfg.llamaSwapUrl;
      model = "jarvis";
      max_tokens = 200;
    };
    tts.url = cfg.llamaSwapUrl;
    character = {
      default = cfg.character;
      dir = "/etc/jarvis/characters";
      base_prompt = "/etc/jarvis/prompts/base.md";
      refs = "${modelsDir}/refs";
    };
    stt = {
      model = "${modelsDir}/stt/whisper-small";
      threads = 4;
    };
    vad.model = "${modelsDir}/silero_vad.onnx";
    wake_word = {
      inherit (cfg.wakeWord) enable;
      model = "${modelsDir}/kws";
    };
    audio = {
      inherit (cfg.audio) source;
      silence_ms = 1000;
      max_record_s = 30;
    };
    history = {
      inherit (cfg.history) turns;
      forget_after_s = 600;
    };
    tools = {
      web_search = if cfg.tools.webSearch == null then "" else cfg.tools.webSearch;
      notes_mcp = if cfg.tools.notesMcp == null then "" else cfg.tools.notesMcp;
      notes_library = "notes";
    };
    ui = {
      open_cmd = cfg.openCmd;
      inherit (cfg) notify;
      ready_sound = "/etc/jarvis/sounds/ready.ogg";
    };
  };

  # the tts server's voice library: a profile per cloned character, the
  # daemon asks for voice "clone:<id>"
  voices = pkgs.linkFarm "jarvis-voices" (
    lib.concatMap (id: [
      {
        name = "profiles/${id}/meta.json";
        path = pkgs.runCommandLocal "jarvis-voice-${id}.json" { nativeBuildInputs = [ pkgs.jq ]; } ''
          jq -n --arg id ${id} --rawfile text ${refs.${id}}/ref.txt \
            '{name: $id, profile_id: $id, ref_audio_filename: "ref.wav", ref_text: $text, x_vector_only_mode: false, language: "Auto"}' > $out
        '';
      }
      {
        name = "profiles/${id}/ref.wav";
        path = "${refs.${id}}/ref.wav";
      }
    ]) cloned
  );

  # what /var/lib/models/jarvis links to
  modelTree = pkgs.linkFarm "jarvis-models" (
    [
      {
        name = "stt/whisper-small";
        path = models.whisper-small;
      }
      {
        name = "kws";
        path = models.kws;
      }
      {
        name = "silero_vad.onnx";
        path = models.silero-vad;
      }
      {
        name = "tts/base";
        path = models.tts-base;
      }
      {
        name = "tts/kurisu";
        path = models.tts-kurisu;
      }
      {
        name = "tts/voices";
        path = voices;
      }
    ]
    ++ map (id: {
      name = "refs/${id}";
      path = refs.${id};
    }) cloned
  );

  # the tts: no llama.cpp server for qwen3-tts (llama-server has no
  # /v1/audio/speech, llama-tts is a cli), so Qwen3-TTS-Openai-Fastapi's
  # rocm image, built here once with podman. llama-swap starts a server
  # through its unit (llama-swap is a sandboxed dynamic user, root runs
  # podman) and stops it with cmdStop
  ttsSrc = pkgs.fetchFromGitHub {
    owner = "groxaxo";
    repo = "Qwen3-TTS-Openai-Fastapi";
    rev = "783bf0e51596f1eb1e70124258f0e1ea4bf3b40a";
    hash = "sha256-8xQPUgXGF0SXMefDSiCDVw8f5g1jGmSk4lVmTE4EivY=";
  };
  # Dockerfile.rocm's FROM (rocm6.3.1, ubuntu 22.04, py3.12, torch 2.6.0)
  # was never published. this one has the same python and torch, and is
  # 10 GB instead of 24 for rocm 6
  ttsBase = "docker.io/rocm/pytorch:rocm7.1_ubuntu24.04_py3.12_pytorch_release_2.6.0";
  ttsImage = "localhost/jarvis-tts:${builtins.substring 0 7 ttsSrc.rev}-rocm7.1";

  # the same ports as proxy in llama-swap/config.yaml
  ttsServers = {
    base = {
      port = 8881;
      path = models.tts-base;
      type = "base";
      speakers = [ ];
    };
    kurisu = {
      port = 8882;
      path = models.tts-kurisu;
      type = "customvoice";
      speakers = [
        "kurisu"
        "amadeus"
      ];
    };
  };

  ttsConfig =
    name: s:
    (pkgs.formats.yaml { }).generate "jarvis-tts-${name}.yaml" {
      default_model = name;
      models.${name} = {
        hf_id = "${s.path}";
        inherit (s) type;
      };
      # no torch.compile: on rocm its warmup compiled for over 3.5 minutes on
      # every cold load (the kernel cache dies with the container) and never
      # finished. without it the server skips its fast streaming paths too,
      # so the 1.7b voice comes at ~0.7x real time (RTF 1.45): the daemon
      # waits for enough of it before it plays, see audio.PlayStream.
      # 72 frames is the readme's decode window for amd
      optimization = {
        attention = "flash_attention_2";
        use_compile = false;
        use_cuda_graphs = false;
        use_fast_codebook = true;
        streaming = {
          decode_window_frames = 72;
          emit_every_frames = 6;
        };
      };
      server = {
        host = "127.0.0.1";
        inherit (s) port;
      };
      voices = map (v: {
        name = v;
        language = "English";
      }) s.speakers;
    };

  # llama-swap's cmd: start the unit, live while it runs
  jarvis-tts = pkgs.writeShellApplication {
    name = "jarvis-tts";
    runtimeInputs = [ pkgs.systemd ];
    text = ''
      unit="jarvis-tts-$1.service"
      trap 'systemctl stop "$unit"; exit 0' TERM INT
      systemctl start "$unit"
      while systemctl is-active -q "$unit"; do
        sleep 2 &
        wait $!
      done
      exit 1
    '';
  };

  # no rounded shapes in jarvis' qml, ever
  noRadius = pkgs.runCommandLocal "jarvis-no-radius" { } ''
    if grep -n radius ${quickshell}/menus/Jarvis.qml ${quickshell}/widgets/MicTile.qml ${quickshell}/widgets/JarvisBar.qml; then
      echo "jarvis: radius in the qml above, its shapes stay square" >&2
      exit 1
    fi
    touch $out
  '';
in
{
  options.services.jarvis = {
    enable = lib.mkEnableOption "jarvis, the local voice assistant";
    character = lib.mkOption {
      type = lib.types.str;
      default = "jarvis";
      description = "The character at the start, a folder in characters/. The menu's pick wins after.";
    };
    wakeWord.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Listen for the active character's wake phrase.";
    };
    audio.source = lib.mkOption {
      type = lib.types.str;
      default = "default";
      description = "The input device. The menu's pick wins after.";
    };
    history.turns = lib.mkOption {
      type = lib.types.int;
      default = 6;
      description = "Exchanges kept for the next question.";
    };
    notify = lib.mkOption {
      type = lib.types.bool;
      # off: the menu comes back when jarvis starts speaking, with the answer
      default = false;
      description = "A notification with the answer while the menu is closed.";
    };
    llamaSwapUrl = lib.mkOption {
      type = lib.types.str;
      default = "http://127.0.0.1:11434";
      description = "llama-swap, it serves the llm and the tts.";
    };
    # what the llm may use, only when the user asks for it. null turns one off
    tools.webSearch = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default =
        if config.services.searx.enable then
          "http://127.0.0.1:${toString (config.services.searx.settings.server.port or 8888)}"
        else
          null;
      description = "searxng for the web search, its json api. The local one when it's on.";
    };
    tools.notesMcp = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      # notes-mcp's port (nixos/services/notes-mcp), on the hosts that import it
      default =
        if config.virtualisation.oci-containers.containers ? notes-mcp then
          "http://127.0.0.1:6281/mcp"
        else
          null;
      description = "The notes' mcp server (docs-mcp-server), its library \"notes\".";
    };
    openCmd = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [
        "qs"
        "-c"
        "hyprland"
        "ipc"
        "call"
        "menu"
        "open"
        "jarvis"
      ];
      description = "What the wake word runs to open the menu.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.elem cfg.character characterDirs;
        message = "services.jarvis.character: no characters/${cfg.character}";
      }
    ];

    environment.systemPackages = [ jarvis ];

    environment.etc = {
      "jarvis/config.toml".source = configFile;
      "jarvis/characters".source = characters;
      "jarvis/prompts".source = ./prompts;
      "jarvis/sounds".source = ./sounds;
    };

    # the models, readable by the user, llama-swap and the tts containers
    systemd.tmpfiles.rules = [
      "d /var/lib/models 0755 root root -"
      "L+ ${modelsDir} - - - - ${modelTree}"
    ];

    system.checks = [ noRadius ];

    systemd.user.services.jarvis = {
      description = "jarvis voice assistant";
      partOf = [ "graphical-session.target" ];
      after = [ "graphical-session.target" ];
      wantedBy = [ "graphical-session.target" ];
      # notify-send, pw-play and qs, from PATH
      path = [
        pkgs.libnotify
        pkgs.pipewire
        pkgs.quickshell
      ];
      serviceConfig = {
        ExecStart = "${lib.getExe jarvis} daemon";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    virtualisation.podman.enable = true;

    systemd.services =
      lib.mapAttrs' (
        name: s:
        lib.nameValuePair "jarvis-tts-${name}" {
          description = "jarvis: qwen3-tts ${name} on :${toString s.port}";
          requires = [ "jarvis-tts-image.service" ];
          after = [ "jarvis-tts-image.service" ];
          serviceConfig = {
            ExecStart = lib.escapeShellArgs [
              podman
              "run"
              "--rm"
              "--replace"
              "--name=jarvis-tts-${name}"
              "--network=host"
              "--ipc=host"
              "--device=/dev/kfd"
              "--device=/dev/dri"
              "--security-opt=seccomp=unconfined"
              # the dgpu only, like llama-swap
              "-e"
              "HIP_VISIBLE_DEVICES=0"
              "-e"
              "HOST=127.0.0.1"
              "-e"
              "PORT=${toString s.port}"
              "-e"
              "TTS_BACKEND=optimized"
              "-e"
              "TTS_CONFIG=/etc/jarvis-tts.yaml"
              "-e"
              "VOICE_LIBRARY_DIR=${voices}"
              "-e"
              "TTS_WARMUP_ON_START=false"
              "-e"
              "GPU_KEEPALIVE_INTERVAL=0"
              "-e"
              "HF_HUB_OFFLINE=1"
              "-v"
              "/nix/store:/nix/store:ro"
              "-v"
              "${ttsConfig name s}:/etc/jarvis-tts.yaml:ro"
              ttsImage
            ];
            ExecStop = "${podman} stop -t 10 jarvis-tts-${name}";
          };
        }
      ) ttsServers
      // {
        # the image is big (rocm pytorch), built once per pinned commit
        jarvis-tts-image = {
          description = "jarvis: build the qwen3-tts server image";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          # the dockerfile's FROM is a short name (rocm/pytorch), this host has
          # no registries.conf to say where those live
          environment = {
            CONTAINERS_REGISTRIES_CONF = pkgs.writeText "jarvis-registries.conf" ''
              unqualified-search-registries = ["docker.io"]
            '';
          }
          // lib.optionalAttrs (proxy != null) {
            # podman pulls through it, and hands it to the build's RUN steps
            # (pip, git): --network=host, so 127.0.0.1 is still xray
            HTTPS_PROXY = proxy;
            HTTP_PROXY = proxy;
            https_proxy = proxy;
            http_proxy = proxy;
            NO_PROXY = "127.0.0.1,localhost";
          };
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            TimeoutStartSec = "3h";
          };
          script = ''
            ${podman} image exists ${ttsImage} ||
              ${podman} build --network=host --from ${ttsBase} -t ${ttsImage} -f Dockerfile.rocm ${ttsSrc}
          '';
        };

        # jarvis-tts, and systemctl for cmdStop
        llama-swap.path = [
          jarvis-tts
          pkgs.systemd
        ];
      };

    # llama-swap starts and stops the tts units without a password
    security.polkit.extraConfig = ''
      polkit.addRule(function (action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" &&
            subject.user == "llama-swap" &&
            /^jarvis-tts-[a-z]+\.service$/.test(action.lookup("unit"))) {
          var verb = action.lookup("verb");
          if (verb == "start" || verb == "stop")
            return polkit.Result.YES;
        }
      });
    '';
  };
}
