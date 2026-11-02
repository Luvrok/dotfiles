# the obsidian vault's history: every 10 minutes whatever changed (by the
# user, livesync or an agent) becomes a commit. only once the vault is a
# repo (git init there), elsewhere it does nothing. roll back with lazygit
# or git restore in the vault
{ config, pkgs, ... }:

let
  vault = "${config.home.homeDirectory}/HOME/wizzard/Holocron";

  # .git/info/exclude, not a .gitignore in the vault: livesync would carry it
  exclude = pkgs.writeText "vault-exclude" ''
    # change on every click
    .obsidian/workspace.json
    .obsidian/workspace-mobile.json
    # livesync's couchdb login and passphrase
    .obsidian/plugins/obsidian-livesync/data.json
    .trash/
  '';

  commit = pkgs.writeShellApplication {
    name = "vault-commit";
    runtimeInputs = with pkgs; [
      git
      coreutils
    ];
    text = ''
      cd ${vault} 2>/dev/null || exit 0
      [ -d .git ] || exit 0
      install -m 644 ${exclude} .git/info/exclude
      # files committed before the exclude was there
      git rm -r -q --cached --ignore-unmatch \
        .obsidian/workspace.json .obsidian/workspace-mobile.json \
        .obsidian/plugins/obsidian-livesync/data.json .trash
      git add -A
      git diff --cached --quiet && exit 0
      git commit -q -m "$(date '+%F %T')"
    '';
  };
in
{
  home.packages = [ commit ];

  systemd.user.services.vault-commit = {
    Unit.Description = "Commit the obsidian vault's changes";
    Service = {
      Type = "oneshot";
      ExecStart = "${commit}/bin/vault-commit";
    };
  };

  systemd.user.timers.vault-commit = {
    Unit.Description = "Commit the obsidian vault's changes every 10 minutes";
    Timer = {
      OnCalendar = "*:0/10";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
