# Хосты и профили

## Профили

### base (включён всегда)

`time.timeZone = "Europe/Moscow"`, vnstat, `galaxy.network.enable`, `stateVersion = "26.05"`.
Всё через `mkDefault`: kessel и tatooine переопределяют часовой пояс на Amsterdam.

### desktop

| Раздел | Что включает |
| --- | --- |
| core | `home`, `users.desktop`, `security.desktop`, `sops`, `boot.systemdBoot`, `boot.pinKernel` |
| сеть | `network.client`, `network.wifi`, интерфейсы `10-eth` (enp14s0) и `20-wifi` (wlan0), порты 7777/8384/22000/61208 |
| desktop | session, packages, xserver, dwm, picom, sddm, pipewire, fonts, dunst, redshift, flameshot, greenclip, statusbar, udevil |
| hardware | qmk |
| programs | kitty, zsh, neovim, rofi, rofi-pass, rofi-bluetooth, rofi-audio, rofi-recording, rofi-translate, librewolf, yazi, mpv, zathura, git, gpg, pass-secret-service, element, shell-proxy, webcam, virtualisation (rofi-wifi — автоматически при iwd) |
| services | zapret, syncthing (от пользователя), jedha-tunnel |

Не включает: llm, searxng, sway — это решает хост.

### laptop

Включается сам при `galaxy.host.isLaptop = true`. Добавляет iwd. `isLaptop` также даёт
`db-battery` и конфиг тачпада (если есть X).

### server (jedha)

`server` (ssh по ключам, en_GB, серверные пакеты, копия репо в `/root/nixos-config`),
`network.client`, sops с host key, glances, syncthing от системного пользователя,
группа `media`, каталоги `/var/lib/media/{downloads,music,books,books/data}` (2775 root:media),
пакеты neovim, glances, openssl, ranger, calibre, tmux.

### vps

`server`, xray (`role = "portal"` по умолчанию), `sops.useHostKey`, ключи ssh barnard и
dash, порты VPS, `gai.conf` с приоритетом IPv4, jq.

## Хосты

### barnard — основной десктоп

```nix
galaxy.host = { gpu = "amd"; dpi = "low"; monitors = [ DP-1 основной 2560x1440@120, DP-0 слева, выключен на экране входа ]; };
galaxy.profiles.desktop.enable = true;
galaxy.files.mutable = true;
galaxy.services.llm.enable = true;
galaxy.services.searxng.enable = true;
galaxy.desktop.xserver.monitorConfig = "…modeline 2560x1440R для обоих DP…";
```

- `dpi = "low"` (109, шрифт 11) — как было фактически. В примере из md было `"high"`,
  это сделало бы всё крупнее.
- mutable-режим: конфиги ссылаются на `~/HOME/infra/dotfiles`.
- LLM: llama-swap с llama.cpp (ROCm + Vulkan + BLAS, `-DGGML_NATIVE=ON`) и
  stable-diffusion.cpp (Vulkan); Open WebUI :11829; LibreChat :3080 (+ MongoDB, Meilisearch);
  pi coding agent; модели в `/var/lib/models`, конфиг `llm/llama-swap/config.yaml`.

### alderaan — ноутбук (hostname `dash`)

```nix
networking.hostName = "dash";
galaxy.host = { user = "dash"; gpu = "nvidia"; dpi = "high"; isLaptop = true; monitors = [ eDP-1 ]; };
galaxy.profiles.desktop.enable = true;
galaxy.services.zapret.testTools = false;
```

- Папка `alderaan`, но машина и пользователь остались `dash`, чтобы не менять ssh-ключи,
  домашний каталог и `dash@dash` в authorized_keys VPS. Алиас в flake:
  `nixosConfigurations.dash`.
- NVIDIA PRIME offload, `10-nvidia.conf`, тачпад, `db-battery`, `QT_SCREEN_SCALE_FACTORS=2;2`.
- В старом варианте этот хост не вычислялся (использовал `sops.*` без модуля sops-nix).

### jedha — домашний сервер (старый ноутбук)

```nix
galaxy.host = { isLaptop = true; sshKeys = [ barnard tunneluser@barnard tunneluser@kessel ]; };
galaxy.profiles.server.enable = true;
galaxy.services = { navidrome kavita koito anki qbittorrent libretranslate zapret = on;
                    xray = { legacyConfig = ./xray.json; role = "bridge"; }; };
boot.loader.grub = { enable = true; device = "/dev/sda"; };
galaxy.network.interfaces = { 10-eth по MAC → .216, 20-wifi → .217 };
galaxy.network.tcpPorts / udpPorts = [ … ];
```

Пользователь `jedha` (wheel, `initialPassword = "nopassword"`), вход только по ключам.
Сервисы публикуют порты в `galaxy.expose` (см. [network.md](network.md#galaxyexpose)).

### kessel, tatooine — VPS в Нидерландах

```nix
imports = [ ./hardware-configuration.nix ./disk-config.nix ];
time.timeZone = "Europe/Amsterdam";
galaxy.profiles.vps.enable = true;
galaxy.services.xray = { legacyConfig = ./xray.json; role = "portal"; };
galaxy.network.interfaces."10-eth" = { match.Name = …; dhcp = false; address = …; gateway = …; };
```

tatooine: `galaxy.host.user = "kessel"` (так было), автологин root на консоли.
Разметка диска — disko (`disk-config.nix`: BIOS boot + ESP + LVM с ext4).

### mos-eisley — VPS в России

Как VPS выше плюс `galaxy.services.nginx.enable = true` (SNI-роутер для `vxrnt.ru`),
свой список портов (добавлены 4110 и 5389), `galaxy.host.user = "kessel"`, автологин root,
часовой пояс Москва (из base).

## Что можно посмотреть командой

```sh
# какие модули включены на хосте
nix eval .#nixosConfigurations.barnard.config.galaxy.programs --apply 'builtins.mapAttrs (_: v: v.enable)' --json

# что опубликовано с jedha
nix eval .#nixosConfigurations.jedha.config.galaxy.expose --json

# порты firewall
nix eval .#nixosConfigurations.kessel.config.networking.firewall.allowedTCPPorts --json
```
