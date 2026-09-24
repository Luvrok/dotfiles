# dotfiles

NixOS + home-manager for all my machines. Every folder in `hosts/` is a machine;
`lib/mkHost.nix` builds it with every module from `modules/` and `profiles/`.

## Layout

| Path | What |
| --- | --- |
| `hosts/<name>/default.nix` | Only `galaxy.*` options and hardware facts |
| `profiles/` | `galaxy.profiles.<name>.enable` turns on a set of modules (`mkDefault`) |
| `modules/core/` | boot, nix, users, network, sops, home-manager, server base |
| `modules/desktop/` | X11, dwm, sddm, picom, dunst, statusbar (`db-*`), fonts… |
| `modules/programs/` | One folder per program: module, config files, scripts |
| `modules/services/` | Services; jedha's publish their ports in `galaxy.expose` |
| `lib/` | `mkHost`, `linkTree`, `mkScript`, xray config generator |
| `pkgs/` | Overlay: dwm, st, slock, dmenu, dwmblocks forks |
| `scripts/deploy` | Switch/update/clean, local or remote |

Hosts: `barnard` (desktop), `alderaan` (laptop, hostname `dash`), `jedha` (home
server), `kessel`, `tatooine`, `mos-eisley` (VPS).

## Options

```nix
{
  imports = [ ./hardware-configuration.nix ];

  galaxy.host = { gpu = "amd"; dpi = "low"; };   # dpi: low = 109, high = 192
  galaxy.profiles.desktop.enable = true;          # also: server, vps, laptop
  galaxy.files.mutable = true;
  galaxy.services.llm.enable = true;
}
```

- `galaxy.files.home.<path> = <file>` links a file into `$HOME` via home-manager.
  With `galaxy.files.mutable = true`, files from this repo link to the checkout at
  `galaxy.files.repoPath` (default `~/HOME/infra/dotfiles`), so edits apply without
  a rebuild. Generated files (`colors.rasi`, kitty `theme.conf`…) always come from
  the store.
- `galaxy.theme.colors` is the only place with colors; kitty, rofi, dunst, zathura,
  flameshot, Xresources, the console and textfoxy read it.
- Scripts are built with `writeShellApplication` (shellcheck, pinned dependencies).

Подробная документация: [docs/](docs/README.md).

## Deploy

```sh
scripts/deploy                 # this machine
scripts/deploy update          # flake update + switch
scripts/deploy kessel 1.2.3.4  # remote
scripts/deploy clean [ip]
```

## Xray

`lib/xray.nix` generates the configs (VLESS + REALITY, VLESS reverse proxy):
jedha is the `bridge`, VPS hosts are `portal`s with a dokodemo-door for every port
in jedha's `galaxy.expose`. For now every host still uses its old encrypted
`xray.json` via `legacyConfig`. To switch a host:

1. Add secrets to its sops file: portal needs `xray/reality_private_key`,
   `xray/short_id`, `xray/bridge_uuid`, `xray/user_<name>`; the bridge needs
   `xray/bridge_uuid_<portal>` and `xray/short_id_<portal>`.
2. Set `galaxy.sops.file` for the VPS (e.g. `../../secrets/kessel.yaml`).
3. Fill `portal.dest`/`portal.serverNames` (or `bridge.portals`), remove `legacyConfig`.
