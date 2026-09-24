# Справочник опций `galaxy.*`

Все опции, объявленные в этом репо. `enable`-опции без пометки по умолчанию `false`.
Колонка «Профиль» — какой профиль включает опцию через `mkDefault`.

## galaxy.host — `modules/host.nix`

| Опция | Тип | По умолчанию | Что делает |
| --- | --- | --- | --- |
| `user` | str | `networking.hostName` | Основной пользователь. Для него создаётся аккаунт и настраивается home-manager |
| `gpu` | `null` / `"amd"` / `"nvidia"` | `null` | Включает `hardware/amd.nix` или `hardware/nvidia.nix`, задаёт `services.xserver.videoDrivers` |
| `dpi` | `"low"` / `"high"` | `"low"` | Задаёт значения по умолчанию для `xftDpi` и `fontSize`. `high` также ставит `QT_*SCALE*` переменные |
| `xftDpi` | int | 109 (low) / 192 (high) | `services.xserver.dpi`, `XFT_DPI` |
| `fontSize` | int | 11 (low) / 14 (high) | Шрифт в kitty, rofi (`font.rasi`), dunst |
| `isLaptop` | bool | `false` | Включает профиль laptop, конфиг тачпада, `db-battery` |
| `monitors` | list of submodule | `[]` | xrandr при старте X-сессии, по порядку списка |
| `sshKeys` | list of str | `[]` | `authorized_keys` для root и основного пользователя |

`monitors.*`:

| Поле | По умолчанию | Во что превращается |
| --- | --- | --- |
| `output` | — | `--output <output>` |
| `mode` | `null` | `--mode <mode>`; `null` = `--auto` |
| `rate` | `null` | `--rate <rate>` |
| `primary` | `false` | `--primary` |
| `leftOf` | `null` | `--left-of <leftOf>` |
| `greeter` | `true` | `false` — выход выключается на экране SDDM (`xrandr --output … --off` в `setupScript`) |

## galaxy.theme — `modules/theme.nix`

| Опция | По умолчанию |
| --- | --- |
| `colors` | gruvbox dark: `bg` `#171717`, `bg0_h` `#1d2021`, `bg0` `#282828`, `bg1` `#3c3836`, `bg2` `#504945`, `gray`, `fg4`…`fg0`, `red` `green` `yellow` `blue` `purple` `aqua` `orange` `#d65d0e`, `bright*`, `black` `#020202` |
| `font` | `"JetBrainsMonoNL Nerd Font"` |

Кто читает — см. [files-and-theme.md](files-and-theme.md#тема).

## galaxy.files — `modules/files.nix`

| Опция | По умолчанию | Что делает |
| --- | --- | --- |
| `home` | `{}` | `{ "<путь от $HOME>" = <файл>; }` → `home.file` в home-manager |
| `mutable` | `false` | Файлы из репо ссылаются на рабочую копию, а не на store |
| `repoPath` | `/home/<user>/HOME/infra/dotfiles` | Где лежит рабочая копия для `mutable` |

## galaxy.lib — встроен в `lib/mkHost.nix`

Read-only. Всё из `lib/default.nix`: `mkHost`, `listModules`, `linkTree`, `mkScript`,
`hexToRgb`, `xray`.

## galaxy.expose — `modules/expose.nix`

`attrsOf { port; subdomain ? null; }`. Сервисы публикуют здесь свои порты; nginx и xray
на других хостах их читают. Подробно — [network.md](network.md#galaxyexpose).

## galaxy.profiles

| Опция | По умолчанию | Файл |
| --- | --- | --- |
| `base.enable` | `true` | `profiles/base.nix` |
| `desktop.enable` | `false` | `profiles/desktop.nix` |
| `laptop.enable` | `galaxy.host.isLaptop` | `profiles/laptop.nix` |
| `server.enable` | `false` | `profiles/server.nix` |
| `vps.enable` | `false` | `profiles/vps.nix` |

Что включает каждый профиль — см. [hosts.md](hosts.md#профили).

## Ядро (`modules/core/`)

| Опция | Профиль | Что делает |
| --- | --- | --- |
| `galaxy.boot.systemdBoot.enable` | desktop | systemd-boot, 20 записей, `editor = false`, `tmp.cleanOnBoot`, grub выключен |
| `galaxy.boot.pinKernel` | desktop | `linuxPackages_6_12` (обход kernel panic в vmalloc на amdgpu, ссылка в комментарии) |
| `galaxy.home.enable` | desktop | home-manager для `galaxy.host.user` |
| `galaxy.users.desktop.enable` | desktop | zsh как оболочка, группы (i2c, kvm, libvirtd, audio, video, input, …), группы vboxsf/plugdev/storage. Без него пользователю ставится `initialPassword = "nopassword"` |
| `galaxy.security.desktop.enable` | desktop | rtkit, polkit, `sudo` без лекции и с `timestamp_timeout=450` |
| `galaxy.sops.enable` | desktop, server; xray без `legacyConfig` | sops-nix |
| `galaxy.sops.file` | `secrets/barnard.yaml` | `sops.defaultSopsFile` |
| `galaxy.sops.useHostKey` | server, vps | расшифровка ssh host key; иначе генерируется age-ключ `/var/lib/sops-nix/key.txt` |
| `galaxy.server.enable` | server, vps | openssh только по ключам, `en_GB.UTF-8`, базовые серверные пакеты, копия репо в `/root/nixos-config`, `/etc/nixos` → папка хоста |
| `galaxy.network.enable` | base | networkd, resolved, firewall |
| `galaxy.network.client.enable` | desktop, server | Без NetworkManager, resolved с Quad9 в качестве fallback, `wait-online` выключен. Без client: `wireless.enable = false`, IPv6, `wait-online.anyInterface` |
| `galaxy.network.wifi.enable` | desktop, laptop | iwd со случайным MAC |
| `galaxy.network.dns` | Quad9 v4+v6 | DNS для networkd/resolved |
| `galaxy.network.interfaces.<unit>` | desktop: `10-eth` enp14s0, `20-wifi` wlan0 | Файлы `systemd.network.networks` |
| `galaxy.network.tcpPorts` / `udpPorts` | desktop, vps (`mkDefault`) | Порты firewall |

`galaxy.network.interfaces.<unit>`:

| Поле | По умолчанию | Смысл |
| --- | --- | --- |
| `match` | — | `[Match]`, например `{ Name = "wlan0"; }` или `{ MACAddress = "…"; }` |
| `dhcp` | `true` | DHCP + DNS-over-TLS + свои DNS. `false` = только статика и `dns` (VPS) |
| `metric` | 20 | `RouteMetric` для DHCPv4 |
| `address` | `null` | Статический адрес |
| `gateway` | `null` | Маршрут по умолчанию с `GatewayOnLink` |

## Десктоп (`modules/desktop/`) — всё включает профиль desktop, кроме sway

| Опция | Что делает |
| --- | --- |
| `session.enable` | Локаль en_US + ru_RU, консоль (цвета из темы), xdg portal, thunar/steam/gamemode/nix-ld/dconf, blueman, earlyoom, thermald, logind, dbus-broker, fstrim, `XFT_DPI`, курсор, gtk/qt, mimeApps, `~/.local/media` |
| `packages.enable` | Большой список системных пакетов + пакеты пользователя |
| `xserver.enable` | X11, xkb us/ru, xrandr по `monitors`, обои, xidlehook, `00-keyboard.conf`, `.Xmodmap`, тачпад на ноутбуках |
| `xserver.monitorConfig` | Текст `xorg.conf.d/60-monitor.conf` (modeline и т.п.) |
| `dwm.enable` | dwm из `pkgs/dwm`, сессия `none+dwm`, `.Xresources` из темы |
| `picom.enable` | HM picom + `picom/picom.conf` |
| `sddm.enable` | SDDM с темой VoidSDDM (gruvbox) |
| `pipewire.enable` | PipeWire 96 kHz, DeepFilter, приоритеты USB-наушников, `.asoundrc` |
| `fonts.enable` | Nerd Fonts, Noto, иконки |
| `dunst.enable` | Уведомления, цвета из темы |
| `redshift.enable` | Redshift, Санкт-Петербург |
| `flameshot.enable` | Flameshot, палитра из темы |
| `greenclip.enable` | greenclip + `rofi-greenclip` |
| `statusbar.enable` | `dwmblocks &` в сессии, скрипты `db-*`, `dwm-volume`, `dwm-brightness` |
| `udevil.enable` | udevil, devmon, udev-правила DualSense и i2c |
| `sway.enable` | `programs.sway` (нигде не включён) |

## Железо (`modules/hardware/`)

| Опция | Что делает |
| --- | --- |
| `galaxy.host.gpu = "amd"` | amdgpu, TearFree, `LIBVA_DRIVER_NAME=radeonsi`, amdgpu_top, btop с ROCm |
| `galaxy.host.gpu = "nvidia"` | NVIDIA open + PRIME offload (Intel 0:2:0, NVIDIA 1:0:0), `10-nvidia.conf` |
| `galaxy.hardware.qmk.enable` (desktop) | qmk, vial, via, keymap-drawer, udev-правила. Раскладки в `qmk/keymaps/` |

## Программы (`modules/programs/`) — включает профиль desktop

| Опция | Что делает |
| --- | --- |
| `kitty.enable` | kitty, `TERMINAL=kitty`, `ssh-term-fix`, `kitty.conf` + сгенерированный `theme.conf`, shell-интеграция в zsh |
| `zsh.enable` | HM zsh (p10k, fzf-tab, autosuggestions, highlighting), fzf, `~/.config/zsh/zshrc`, `~/.p10k.zsh` |
| `neovim.enable` | HM neovim + vim, `~/.config/nvim` из `config/` |
| `rofi.enable` | HM rofi (+rofi-calc), `~/.config/rofi/*.rasi`, `colors.rasi`/`font.rasi` генерятся, скрипты `rofi-menu`, `rofi-powermenu`, `rofi-killer`, `rofi-askpass` |
| `rofi-pass.enable` | Форк rofi-pass, `~/.config/rofi-pass/config`, pass/pwgen/pinentry, переменные `PASSWORD_STORE_DIR`, `ROFI_PASS_*` |
| `rofi-wifi.enable` | По умолчанию = iwd включён **и** rofi включён |
| `rofi-bluetooth.enable` | Меню bluetoothctl |
| `rofi-audio.enable` | Выбор выхода wpctl |
| `rofi-recording.enable` | Запись экрана ffmpeg |
| `rofi-translate.enable` | Переводчик: LibreTranslate на jedha + translate-shell |
| `librewolf.enable` | LibreWolf и Firefox: профили life/work, политики, расширения, textfoxy, rofi tab switcher, `rofi-librewolf`, `BROWSER`, `MOZ_X11_EGL` |
| `yazi.enable` | yazi с плагинами и keymap |
| `mpv.enable` | mpv с форком Luvrok/mpv-config и своими `mpv.conf`/`input.conf` |
| `zathura.enable` | zathura, цвета из темы |
| `git.enable` | git, gh, git-crypt |
| `gpg.enable` | gpg-agent с pinentry-rofi (тема `keyring.rasi`) |
| `pass-secret-service.enable` | Secret Service поверх pass |
| `element.enable` | Element Desktop |
| `shell-proxy.enable` | `shell-proxy` (для `source`), throne с TUN, `proxychains.conf`, xray/sing-box для v2rayN |
| `webcam.enable` | `webcam`: окно ffplay с камерой телефона |
| `virtualisation.enable` | libvirt/QEMU, virt-manager, автозапуск сети default, `virbr0` в trusted |

## Сервисы (`modules/services/`)

| Опция | Кто включает | Что делает |
| --- | --- | --- |
| `zapret.enable` | desktop, jedha | zapret-discord-youtube, конфиг `general(ALT)` |
| `zapret.testTools` | `true` | Утилиты для тестов (на alderaan выключены) |
| `syncthing.enable` | desktop, server | Syncthing |
| `syncthing.systemUser` | = профиль server | `true`: пользователь `syncthing` в группе `media`, `/var/lib/syncthing`, UMask 0002. `false`: от основного пользователя, `~/.config/syncthing` |
| `syncthing.relay` | `false` | Разрешить публичные relay |
| `jedha-tunnel.enable` | desktop | SSH-туннель к jedha и sshfs-монтирования `/media/jedha-*` |
| `llm.enable` | barnard | llama-swap :11434, Open WebUI :11829, LibreChat :3080, pi |
| `searxng.enable` | barnard | SearXNG на 127.0.0.1:11433 |
| `glances.enable` | server | Веб-интерфейс glances, `expose.glances` = 8208 |
| `navidrome.enable` | jedha | :4533, `expose` → `navidrome` |
| `kavita.enable` | jedha | :4545 → `kavita` |
| `koito.enable` | jedha | :4110 → `koito` |
| `anki.enable` | jedha | anki-sync-server :8130 → `anki` |
| `qbittorrent.enable` | jedha | :8129 → `qbt` |
| `libretranslate.enable` | jedha | :5389 → `lt` |
| `nginx.enable` | mos-eisley | SNI-маршрутизация :443 и vhosts из `expose` |
| `nginx.domain` / `from` / `acmeEmail` | `vxrnt.ru` / `jedha` / … | |
| `xray.enable` | vps, jedha | Xray |
| `xray.legacyConfig` | `null` | Готовый JSON вместо генерации (сейчас задан на всех хостах) |
| `xray.role` | `"portal"` | `portal` или `bridge` |
| `xray.portal.*` | | `listen`, `port`, `dest`, `serverNames`, `users`, `exposeFrom`, `exposeListen` |
| `xray.bridge.portals.<name>` | `{}` | `address`, `port`, `serverName`, `publicKey` |

Подробно о сетевых сервисах — [network.md](network.md).
