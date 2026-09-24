# Что изменилось по сравнению со старой структурой

Старый вариант: коммит `9d0fe0b`. Новый: `35eaf7e` и дальше.

## Идея

| | Было | Стало |
| --- | --- | --- |
| Сборка хостов | Каждый хост вручную прописан в `flake.nix`: свой `nixosSystem`, свой список модулей, свой `pkgs`, свой `specialArgs.username` | Каждая папка в `hosts/` — хост. `lib/mkHost.nix` собирает его одинаково для всех |
| Что подключено к хосту | Десктопы: `./nixos` целиком (всё сразу). Серверы: файлы из своей папки | Все модули подключены везде, но выключены. Включение — через опции |
| Настройка хоста | `nixos/config/<host>.nix` (videoDrivers/dpi/fontSize) + `hosts/<host>/env.nix` (переменные, xorg-конфиги) + условия `if hostName == "barnard"` в модулях | `hosts/<name>/default.nix` с `galaxy.host.*` и включением профилей/сервисов |
| Пользовательская часть | `home/` — отдельное дерево home-manager с `extraSpecialArgs` (`username`, `fontSize`, `dpi`, …) | HM-часть каждой программы лежит в её модуле в `modules/programs/<name>` |
| Параметры | `username` через `specialArgs`, опции `videoDrivers`/`dpi`/`fontSize` без пространства имён | Всё в `galaxy.*`, пользователь — `galaxy.host.user` |
| Скрипты | `home/local/sh/*` копируются в `~/.local/bin` | Пакеты `writeShellApplication` рядом с модулем, в `PATH` системы |
| Цвета | Захардкожены в dunst, zathura, kitty, rofi, flameshot, Xresources, консоли | `galaxy.theme.colors` |
| Порты сервисов | Одно число в сервисе, в nginx.nix, в xray.json, в firewall | Сервис объявляет `galaxy.expose`, nginx читает оттуда |
| Xray | Четыре зашифрованных `xray.json` | Генератор `lib/xray.nix` + модуль с секретами из sops (пока включён legacy) |
| Деплой | `sapply`, `supdate`, `sclean`, `*-remote` в `~/.local/bin` | `scripts/deploy` в репо |

## Куда что переехало

### nixos/

| Было | Стало |
| --- | --- |
| `nixos/default.nix` (локаль, консоль, nix, sudo, пользователи, portal, programs, sops) | `core/nix.nix`, `core/users.nix`, `core/security.nix`, `core/sops.nix`, `desktop/session.nix` |
| `nixos/boot.nix` | `core/boot.nix` (`galaxy.boot.systemdBoot`) |
| закрепление ядра 6.12 в `flake.nix` | `core/boot.nix` (`galaxy.boot.pinKernel`, комментарий сохранён) |
| `nixos/network.nix` | `core/network.nix` + интерфейсы в профиле desktop |
| `nixos/security.nix` | `core/security.nix` |
| `nixos/env.nix` | разнесено: `TERMINAL` → kitty, `BROWSER`/`MOZ_X11_EGL` → librewolf, `PASSWORD_STORE_DIR`/`ROFI_PASS_*` → rofi-pass, `UDEVIL_CONF_PATH` → udevil, `TERM`/`TOR_SOCKS_PORT`/`localBinInPath` → session, `00-keyboard.conf` → xserver, `proxychains.conf` → shell-proxy |
| `nixos/options.nix` (`videoDrivers`, `dpi`, `fontSize`) | `modules/host.nix` (`galaxy.host.gpu`, `dpi`, `xftDpi`, `fontSize`) |
| `nixos/config/barnard.nix`, `alderaan.nix` | `hosts/<name>/default.nix` |
| `nixos/packages.nix` | `desktop/packages.nix` |
| `nixos/hardware/{amd,nvidia}.nix` | `hardware/{amd,nvidia}.nix` (включаются по `galaxy.host.gpu`) |
| `nixos/modules/fonts.nix` | `desktop/fonts.nix` |
| `nixos/modules/qmk/` | `hardware/qmk/` (раскладки в `keymaps/`) |
| `nixos/modules/virtualisation.nix` | `programs/virtualisation.nix` |
| `nixos/modules/udevil.nix` | `desktop/udevil.nix` |
| `nixos/services/default.nix` | разнесено: syncthing, llama-swap → llm, logind/dbus/earlyoom/… → session, `defaultSession` → dwm |
| `nixos/services/{xserver,sddm,pipewire,greenclip}.nix` | `desktop/…` |
| `nixos/services/{searxng,syncthing,jedha-tunnel}.nix` | `services/…` |
| `nixos/services/{librechat.nix,open-webui/,llama-swap/}` | `services/llm/` |
| `nixos/overlays/default.nix` | `pkgs/default.nix` + `pkgs/<name>/default.nix` |
| `nixos/overlays/mpv/` + derivation `mpv-config` | `programs/mpv/` |
| llama-cpp с ROCm в overlay | `services/llm/llama-swap/default.nix` (локально) |
| `nixos/overlays/extraShell.nix` | `pkgs/extraShell.nix` → пакет `ssh-term-fix`, ставит kitty |

### home/

| Было | Стало |
| --- | --- |
| `home/default.nix` (HM-база, mimeApps, gtk, qt, курсор) | `core/home.nix` + `desktop/session.nix` |
| `.Xresources` | `desktop/dwm.nix` (цвета из темы) |
| `.Xmodmap` | `desktop/xserver.nix` |
| `.config/.asoundrc` | `desktop/pipewire.nix` |
| `greenclip.toml` | `desktop/greenclip.nix` |
| v2rayN-ссылки на xray/sing-box | `programs/shell-proxy` |
| `home/packages.nix` | `desktop/packages.nix` (HM-часть), pass/pinentry/pwgen → rofi-pass, pass-secret-service/libsecret → pass-secret-service, kitty → kitty |
| `home/picom.nix` | `desktop/picom/{default.nix,picom.conf}` |
| `home/services/{dunst,redshift,flameshot}.nix` | `desktop/…` |
| `home/services/pass-secret-service.nix` | `programs/pass-secret-service.nix` |
| `home/programs/kitty.nix` | `programs/kitty/` (`config/kitty.conf` + генерируемый `theme.conf`) |
| `home/programs/zsh/` | `programs/zsh/` (`config/zshrc`, `config/p10k.zsh`) |
| `home/programs/neovim/nvim` | `programs/neovim/config` |
| `home/programs/rofi/config` | `programs/rofi/config` |
| `home/programs/rofi/font/*.rasi`, `config/colors.rasi` | генерируются в `programs/rofi/default.nix` |
| `home/programs/rofi/rofi-pass.nix` | `programs/rofi-pass/config.nix` |
| `home/programs/librewolf/*` | `programs/librewolf/`, JSON-бэкапы в `config/`, `sidebery-data-2026….json` → `config/sidebery.json` |
| `home/programs/{yazi,zathura,git,gpg,mpv,element-desktop}` | `programs/…` |
| `home/programs/llm-home.nix` | `services/llm/pi.nix` (HM-модуль) |
| `home/local/media` | `desktop/media` |
| `home/local/sh/*` | см. [scripts.md](scripts.md#где-что-лежит) |
| `sapply`, `supdate`, `sclean`, `*-remote` | `scripts/deploy` |

### hosts/

| Было | Стало |
| --- | --- |
| `hosts/{barnard,alderaan}/env.nix` | `hosts/<name>/default.nix` (мониторы — `galaxy.host.monitors` + `monitorConfig`), `10-nvidia.conf` → `hardware/nvidia.nix`, тачпад → `xserver.nix` |
| `hosts/jedha/{navidrome,kavita,koito,anki,qbittorrent,libretranslate,glances,syncthing}.nix` | `services/…` с опциями и `galaxy.expose` |
| `hosts/jedha/network.nix` | `galaxy.network.*` в `hosts/jedha` |
| `hosts/mos-eisley/nginx.nix` | `services/nginx.nix` (vhosts из `expose` jedha) |
| общий код трёх VPS (ssh, пользователи, копия репо, xray-настройки, пакеты) | `core/server.nix`, `profiles/vps.nix`, `services/xray.nix` |
| `xray.json` | остались на месте, подключены через `legacyConfig` |

## Изменения поведения

Проверено сравнением вычисленных конфигов (пакеты, `/etc`, systemd-юниты, пользователи,
firewall, файлы home-manager) и сравнением замыканий `.drv`.

### Серверы

| Хост | Разница |
| --- | --- |
| kessel, tatooine | `NIX_PATH=nixpkgs=<store>` и `warn-dirty = false` (теперь на всех хостах), путь копии репо |
| mos-eisley | то же + порядок строк в `map` nginx (смысл тот же) |
| jedha | то же + `syncthing-init.service` (из-за `relaysEnabled = false`) |

### Десктопы

| Что | Было | Стало |
| --- | --- | --- |
| Скрипты | `~/.local/bin/*` | в системном `PATH`, с закреплёнными зависимостями и shellcheck |
| `db-battery` | на всех десктопах | только при `isLaptop` |
| `rofi-pass` | ваш форк в `~/.local/bin` + upstream-пакет из HM | только форк |
| kitty | HM `programs.kitty` | пакет + `kitty.conf` + `theme.conf`; интеграция с zsh та же |
| `.zshrc` | zshrc вклеен | `source ~/.config/zsh/zshrc` |
| `llm-off` | алиас в zshrc | HM `shellAliases` в модуле llm |
| nvim `init.lua` | HM генерировал свой, конфликтовал с вашим | HM-версия отключена |
| picom | всё в HM settings | HM-опции + `picom.conf` через `extraConfig`; итоговый набор ключей тот же |
| rofi `font.rasi` | `font-dpi-low/high` по `fontSize < 14` | генерируется с `fontSize` |
| `.local/media`, `.config/rofi`, `.config/nvim` | одна ссылка на папку (recursive) | ссылка на каждый файл (`linkTree`) |
| barnard | — | mutable-режим: ссылки ведут в рабочую копию |
| Syncthing | без настроек | `relaysEnabled = false`, `overrideDevices/Folders = false` (устройства и папки из GUI не трогаются) |
| `XCURSOR_*`, `unset SSH_ASKPASS` | только barnard | все десктопы |
| `00-keyboard.conf` на ноутбуке | секция была записана дважды | один раз |
| LLM, SearXNG | формально и на dash | только barnard |
| zapret на dash | модуль без test tools | то же (`testTools = false`) |
| alderaan | не вычислялся (нет модуля sops-nix) | вычисляется |

### Удалено

- Папки `nixos/` и `home/`, `hosts/*/env.nix`, `hosts/jedha/network.nix`, дублирующий
  `hosts/jedha/syncthing.nix`.
- `nixos/config/*.nix` и опции `videoDrivers`/`dpi`/`fontSize`.
- Передача `username` и `pkgs` через `specialArgs`.

### Не сделано (есть в плане, но не было в конфиге)

- `clock-rs`, `qutebrowser`, `terraria` (порт 7777 остался в списке портов десктопа),
  lanzaboote/LUKS/TPM. Модуль `sway` создан, но нигде не включён.
- Разделение `secrets/barnard.yaml` на файлы по хостам: файлы зашифрованы, ключа не было.
- Переход xray на генератор: см. [network.md](network.md#переход-на-генератор).

## Технические отличия, которые стоит знать

- **pkgs**: раньше `pkgs` создавался в flake (`import nixpkgs { config.allowUnfree … }`) и
  передавался в `nixosSystem`, overlay при этом применялся поверх. Теперь NixOS создаёт
  pkgs сам из `nixpkgs.config` + `nixpkgs.overlays` (`core/nix.nix`). Overlay применяется на
  всех хостах; на серверах это ничего не меняет — там форки не используются.
- **Внешние модули** (home-manager, sops-nix, disko, zapret) подключены на всех хостах.
  Без настроек они ничего не добавляют (проверено сравнением VPS).
- **Ссылки между хостами**: nginx и xray на VPS читают `galaxy.expose` jedha через `self`.
  Раньше эти порты приходилось держать в синхронизации руками.
- **Приоритеты**: профиль задаёт всё через `mkDefault`, поэтому хост может выключить любой
  модуль профиля одной строкой.
- **Форматирование**: весь Nix отформатирован `nixfmt`, для этого есть `nix fmt`.
