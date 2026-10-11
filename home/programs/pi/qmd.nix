{
  config,
  pkgs,
  inputs,
  ...
}:
let
  vaultRel = "HOME/wizzard/Gringotts-Grid";
  vault = "${config.home.homeDirectory}/${vaultRel}";

  qmdUpstream = inputs.qmd.packages.${pkgs.stdenv.hostPlatform.system}.default;

  qmd = pkgs.writeShellScriptBin "qmd" ''
    export QMD_FORCE_CPU="''${QMD_FORCE_CPU:-1}"
    export QMD_EMBED_MODEL="''${QMD_EMBED_MODEL:-/var/lib/models/Qwen3-Embedding-0.6B-Q8_0.gguf}"

    if [ -n "''${XDG_RUNTIME_DIR:-}" ] && [ -S "$XDG_RUNTIME_DIR/bus" ]; then
      exec ${pkgs.systemd}/bin/systemd-run --user --scope --quiet --collect \
        -p CPUQuota="''${QMD_CPU_QUOTA:-400%}" \
        ${qmdUpstream}/bin/qmd "$@"
    fi
    exec ${qmdUpstream}/bin/qmd "$@"
  '';

  qmdSkill = pkgs.writeTextDir "SKILL.md" ''
    ---
    name: qmd
    description: Search the user's Obsidian notes (Russian and English) with the qmd CLI. Use whenever the user asks what is in their notes, asks to find a note, or asks about something their notes may cover.
    ---

    # Searching the notes with qmd

    qmd is a shell command. Run it with your bash/shell tool exactly as shown
    below. There is no qmd tool and no JavaScript API.

    The notes are in Russian and English. A note can be in either language,
    whatever the language of the question.

    ## Steps

    1. Keyword search, in both languages:
       `qmd search "испанск" -n 5 --full`
       `qmd search "spanish" -n 5 --full`
       One or two word stems per call, one language per call: every word must
       match. Stems match word beginnings (`испанск` finds "испанского").
       Also try abbreviations, e.g. `спб` for Санкт-Петербург.

    2. If step 1 found nothing relevant, search by meaning:
       `qmd vsearch "школы испанского языка в Санкт-Петербурге" -n 5 --full`
       `qmd vsearch "Spanish language schools in Saint Petersburg" -n 5 --full`

    `--full` prints each found note in full. Read the whole text of every
    found note before answering: the relevant part is often a section further
    down, under a heading in either language.

    ## Rules

    - Do not use `qmd query`.
    - Say the notes have nothing only after steps 1 and 2 in both languages.
    - Answer from the note text and name the note path.
    - Reply in the language of the user's question, including intermediate
      messages.
    - Never pipe qmd output through `head`, `sed` or `tail`.
  '';

  qmdIndex = {
    global_context = "Personal Obsidian vault. Notes are in Russian and English.";

    collections.notes = {
      path = vault;
      pattern = "**/*.md";
      ignore = [
        ".obsidian/**"
        ".trash/**"
        ".opencode/**"
        "copilot/**"
      ];
      context."/" = "Obsidian vault";
    };
  };

  qmdIndexScript = pkgs.writeShellScript "qmd-index" ''
    ${qmd}/bin/qmd update && ${qmd}/bin/qmd embed
  '';
in
{
  home.packages = [ qmd ];

  xdg.configFile."qmd/index.yml".text = builtins.toJSON qmdIndex;

  home.file = {
    ".pi/agent/skills/qmd".source = qmdSkill;
    "${vaultRel}/.opencode/skills/qmd" = {
      source = qmdSkill;
      recursive = true;
    };
  };

  systemd.user.services.qmd-index = {
    Unit.Description = "Re-index Obsidian vault for qmd";
    Service = {
      Type = "oneshot";
      ExecStart = "${qmdIndexScript}";
      Environment = "QMD_CPU_QUOTA=200%";
      Nice = 19;
      IOSchedulingClass = "idle";
    };
  };

  systemd.user.timers.qmd-index = {
    Unit.Description = "Re-index Obsidian vault for qmd";
    Timer = {
      OnBootSec = "5min";
      OnUnitActiveSec = "30min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
