# Скрипты

## Как собираются

Раньше все скрипты лежали в `home/local/sh/` и копировались в `~/.local/bin` целиком.
Теперь каждый скрипт лежит рядом с модулем, к которому относится, и собирается через
`writeShellApplication`:

```nix
config.galaxy.lib.mkScript pkgs {
  name = "rofi-wifi";
  src = ./rofi-wifi;
  runtimeInputs = with pkgs; [ rofi iwd libnotify gnused gawk ];
  excludeShellChecks = [ ];   # необязательно
}
```

`mkScript` (`lib/default.nix`) делает следующее:

- `writeShellApplication` с `text = readFile src`. Первая строка `#!/bin/sh` остаётся
  комментарием, интерпретатор — bash из nixpkgs. На NixOS `/bin/sh` и так bash, поэтому
  bash-конструкции (`<<<`, `<(…)`) работают как раньше.
- `bashOptions = [ ]`: без `set -euo pipefail`. Скрипты писались без него, и `-u`/`-e`
  сломали бы, например, `db-battery` (`$capacity` при первом проходе не задана).
- `runtimeInputs` дописываются **в начало** `PATH`: зависимости закреплены, остальное
  по-прежнему ищется в системном `PATH`.
- При сборке запускается shellcheck. Ошибка shellcheck = ошибка сборки. Для пяти скриптов
  отключены конкретные коды, чтобы не трогать их код:

| Скрипт | Отключено |
| --- | --- |
| `db-memory` | SC2005 |
| `rofi-audio` | SC2086, SC2126 |
| `rofi-bluetooth` | SC2086 |
| `rofi-pass` | SC1090, SC2034 |
| `rofi-recording` | SC2034 |

Готовые пакеты ставятся в `environment.systemPackages`. Имена не менялись: их вызывают
dwm (`config.h`) и dwmblocks по имени.

## Где что лежит

| Скрипт | Файл | Модуль / опция | Зависимости (`runtimeInputs`) |
| --- | --- | --- | --- |
| `db-date` | `desktop/statusbar/scripts/` | `desktop.statusbar` | coreutils |
| `db-memory` | ″ | ″ | procps, gawk, gnused |
| `db-rec` | ″ | ″ | coreutils |
| `db-volume` | ″ | ″ | wireplumber, gawk, gnugrep |
| `db-wifi` | ″ | ″ | iwd, iw, iproute2, gawk, gnugrep |
| `db-xkb` | ″ | ″ | xset, xkb-switch, gawk, gnugrep |
| `db-battery` | ″ | ″, только при `host.isLaptop` | coreutils |
| `dwm-volume` | ″ | ″ | wireplumber, libnotify, procps, gawk, gnugrep |
| `dwm-brightness` | ″ | ″ | ddcutil, libnotify, gawk |
| `rofi-menu` | `programs/rofi/scripts/` | `programs.rofi` | rofi, dmenu, coreutils, gawk, gnugrep, gnused |
| `rofi-powermenu` | ″ | ″ | rofi, procps |
| `rofi-killer` | ″ | ″ | rofi, procps |
| `rofi-askpass` | ″ | ″ | rofi |
| `rofi-greenclip` | `desktop/rofi-greenclip` | `desktop.greenclip` | rofi |
| `rofi-pass` | `programs/rofi-pass/` | `programs.rofi-pass` | rofi, pass, xclip, xdotool, libnotify |
| `rofi-wifi` | `programs/rofi-wifi/` | `programs.rofi-wifi` | rofi, iwd, libnotify, gnused, gawk |
| `rofi-bluetooth` | `programs/rofi-bluetooth/` | `programs.rofi-bluetooth` | rofi, bluez, bc, util-linux, libnotify, gnused |
| `rofi-audio` | `programs/rofi-audio/` | `programs.rofi-audio` | rofi, wireplumber, gnugrep, gnused, coreutils, findutils |
| `rofi-recording` | `programs/rofi-recording/` | `programs.rofi-recording` | rofi, ffmpeg-full, slop, xrandr, xdpyinfo, pulseaudio, wireplumber, procps, libnotify, gawk, gnused |
| `rofi-translate` | `programs/rofi-translate/` | `programs.rofi-translate` | rofi, translate-shell, jq, curl, xclip, libnotify, gawk, gnused |
| `rofi-librewolf` | `programs/librewolf/` | `programs.librewolf` | rofi, gawk, gnugrep, coreutils |
| `webcam` | `programs/webcam/` | `programs.webcam` | ffmpeg-full, xdpyinfo, gawk, libnotify |
| `shell-proxy` | `programs/shell-proxy/` | `programs.shell-proxy` | — |
| `ssh` (обёртка `TERM=xterm`) | `pkgs/extraShell.nix` | `programs.kitty` | openssh |

Отдельно:

- `shell-proxy` предназначен для `source shell-proxy`: zsh ищет файл в `PATH`, а в
  сгенерированном скрипте кроме шебанга и `export PATH="$PATH"` ничего лишнего нет.
- `rofi-pass` — ваш урезанный форк. Он читает `~/.config/rofi-pass/config`, который
  генерируется из `programs/rofi-pass/config.nix`: функция `_rofi` с клавишами из HM
  `programs.rofi.extraConfig` (без `Control+n`/`Control+p`), `_pwgen`, настройки
  буфера обмена и автоввода. Upstream-пакет `rofi-pass` больше не ставится.
- `rofi-translate` использует `trans`, если он есть. Теперь translate-shell есть всегда.
  `espeak-ng` и `dunstify` скрипт ищет через `command -v` в системном `PATH`.

## scripts/deploy

Скрипт для ручного запуска. Через систему не ставится, запускается из репо.
Заменяет `sapply`, `supdate`, `sclean`, `sapply-remote`, `sclean-remote`.

| Команда | Было | Что делает |
| --- | --- | --- |
| `scripts/deploy` | `sapply` | `nh os switch <repo>#$(hostname)` |
| `scripts/deploy update` | `supdate` | `nh os switch -u …` (flake update + switch) |
| `scripts/deploy <host> <ip>` | `sapply-remote <ip> <host>` | `nh os switch <repo>#<host> -H <host> --target-host root@<ip>` |
| `scripts/deploy clean` | `sclean` | `nh clean all && nix profile wipe-history && nix store optimise` |
| `scripts/deploy clean <ip>` | `sclean-remote <ip>` | то же по ssh от root |

Отличия от старых скриптов:

- Путь к flake определяется по расположению скрипта, а не зашит как `~/HOME/infra/dotfiles`.
- Хост выбирается по `hostname`, а не по `$USER`. На ноутбуке hostname `dash`, для него в
  flake есть алиас `dash = alderaan`.
- У удалённого деплоя порядок аргументов: сначала имя, потом IP.
- Уведомление и звук (`~/.local/media/soundeffect/*`) как раньше.
