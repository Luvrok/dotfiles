# Рецепты

## Новый хост

1. `mkdir hosts/<name>` и положить туда `hardware-configuration.nix`
   (`nixos-generate-config --show-hardware-config`). Для VPS ещё `disk-config.nix` (disko).
2. `hosts/<name>/default.nix`:

   ```nix
   {
     imports = [ ./hardware-configuration.nix ];

     galaxy.host = { gpu = "amd"; dpi = "high"; };
     galaxy.profiles.desktop.enable = true;
   }
   ```

3. `git add hosts/<name>` (flake видит только файлы, известные git) и
   `nix eval .#nixosConfigurations.<name>.config.system.build.toplevel.drvPath`.

hostname = имя папки, пользователь = hostname. Переопределяются через
`networking.hostName` и `galaxy.host.user`.

## Новая программа

```
modules/programs/foo/
  default.nix
  config/foo.conf
```

```nix
{ config, lib, pkgs, ... }:
{
  options.galaxy.programs.foo.enable = lib.mkEnableOption "foo";

  config = lib.mkIf config.galaxy.programs.foo.enable {
    environment.systemPackages = [ pkgs.foo ];
    galaxy.files.home.".config/foo/foo.conf" = ./config/foo.conf;
    # или целая папка:
    # galaxy.files.home = config.galaxy.lib.linkTree ".config/foo" ./config;
  };
}
```

Импортировать ничего не нужно: модуль подхватит `listModules`. Включить — в профиле
(`foo.enable = on;` в `profiles/desktop.nix`) или в хосте.

Если нужна настройка через home-manager:

```nix
home-manager.users.${config.galaxy.host.user} = { config, ... }: {
  programs.foo.enable = true;
  programs.foo.cacheDir = "${config.xdg.cacheHome}/foo";   # здесь config — это HM
};
```

Если нужны цвета — `let c = config.galaxy.theme.colors; in …`. Файл, который зависит от
темы или DPI, генерируется `pkgs.writeText` и тоже кладётся через `galaxy.files.home`.

## Новый скрипт

Положить файл рядом с модулем и добавить:

```nix
environment.systemPackages = [
  (config.galaxy.lib.mkScript pkgs {
    name = "foo-menu";
    src = ./foo-menu;
    runtimeInputs = with pkgs; [ rofi libnotify ];
  })
];
```

Если shellcheck ругается, а менять код не хочется: `excludeShellChecks = [ "SC2086" ];`.
Собрать и проверить:

```sh
nix build --impure --expr '(builtins.getFlake (toString ./.)).nixosConfigurations.barnard.config.environment.systemPackages' --no-link
```

(или просто `nix flake check`, он соберёт весь toplevel).

## Новый сервис на jedha, доступный из интернета

```nix
# modules/services/foo.nix
{ config, lib, ... }:
{
  options.galaxy.services.foo.enable = lib.mkEnableOption "foo";

  config = lib.mkIf config.galaxy.services.foo.enable {
    galaxy.expose.foo = { port = 4600; subdomain = "foo"; };
    services.foo = { enable = true; port = config.galaxy.expose.foo.port; };
  };
}
```

Потом:

- `galaxy.services.foo.enable = true;` в `hosts/jedha`;
- порт в firewall jedha (`galaxy.network.tcpPorts`) и, если нужен доступ по IP, VPS;
- nginx на mos-eisley создаст `foo.vxrnt.ru` сам;
- в xray: пока используется `legacyConfig`, dokodemo-door для порта нужно добавить в
  старый `xray.json` вручную. После перехода на генератор — ничего делать не нужно.

## Новый секрет

1. `sops secrets/barnard.yaml` (или файл хоста) и добавить ключ.
2. В модуле:

   ```nix
   sops.secrets."foo/token" = { restartUnits = [ "foo.service" ]; };
   services.foo.tokenFile = config.sops.secrets."foo/token".path;
   ```

3. На хосте должно быть `galaxy.sops.enable = true` (уже есть на desktop и server).

Новый хост-получатель: публичный age-ключ (`ssh-to-age < /etc/ssh/ssh_host_ed25519_key.pub`)
добавить в `.sops.yaml` и выполнить `sops updatekeys secrets/<file>.yaml`.

## Изменить цвет или шрифт

`modules/theme.nix`, либо в хосте:

```nix
galaxy.theme.colors.orange = "#fe8019";
galaxy.host.fontSize = 12;
```

## Отключить что-то из профиля на одном хосте

```nix
galaxy.programs.element.enable = false;      # обычный приоритет побеждает mkDefault профиля
galaxy.network.tcpPorts = [ 22 ];            # заменяет список профиля целиком
```

## Работа в mutable-режиме

- Правка существующего файла в `modules/**/config/` видна сразу.
- Новый файл или переименование → `scripts/deploy`.
- Проверить, куда ведёт ссылка: `readlink -f ~/.config/kitty/kitty.conf`.
