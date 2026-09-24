# Документация dotfiles

Конфигурация NixOS + home-manager для всех машин. Одна flake, шесть хостов,
все настройки хостов делаются через опции `galaxy.*`.

| Документ | О чём |
| --- | --- |
| [architecture.md](architecture.md) | Как собирается система: flake → mkHost → модули → профили → хост. Приоритеты, specialArgs, home-manager, overlay |
| [options.md](options.md) | Справочник по всем опциям `galaxy.*` |
| [files-and-theme.md](files-and-theme.md) | `galaxy.files`, mutable-режим, `linkTree`, тема и сгенерированные файлы |
| [scripts.md](scripts.md) | Скрипты (`writeShellApplication`), где какой лежит, `scripts/deploy` |
| [network.md](network.md) | Сеть, `galaxy.expose`, xray-туннель, nginx, jedha-tunnel, sops |
| [hosts.md](hosts.md) | Каждый хост: что включено и почему |
| [recipes.md](recipes.md) | Как добавить хост, программу, сервис, скрипт, секрет |
| [changes.md](changes.md) | Что поменялось по сравнению со старой структурой (`nixos/` + `home/`) |

## Коротко

```
flake.nix
  └─ lib/mkHost.nix  (для каждой папки в hosts/)
       ├─ hosts/<name>/default.nix      ← только galaxy.* и железо
       ├─ modules/**                    ← всё, что умеет система; всё выключено по умолчанию
       ├─ profiles/*.nix                ← наборы mkDefault-включений
       └─ home-manager, sops-nix, disko ← внешние модули
```

- Модули ничего не делают, пока их не включить (`galaxy.<раздел>.<имя>.enable`).
- Профиль — это список включений с `lib.mkDefault`: хост может перекрыть любое из них.
- Хост — это «что это за машина»: GPU, DPI, мониторы, профиль, пара сервисов.
- home-manager остаётся бэкендом для пользовательских файлов и сервисов, но папки
  `home/` больше нет: HM-часть каждой программы лежит в её модуле.

## Команды

```sh
nix flake check --no-build                  # вычислить все хосты
nix fmt                                     # nixfmt-tree по всему репо
scripts/deploy                              # switch текущей машины
scripts/deploy update                       # flake update + switch
scripts/deploy kessel 45.38.20.187          # switch удалённого хоста
scripts/deploy clean [ip]                   # сборка мусора
nix eval .#nixosConfigurations.barnard.config.galaxy.host --json   # посмотреть опции
```
