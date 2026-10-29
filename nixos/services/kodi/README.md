---
tags: [nixos, kodi, barnard]
---

# kodi: раскладка и разбор правок

Сервис kodi на barnard: библиотека `/media/outer-1`, majan, tmdb helper,
movie pipe (radarr/sonarr, см. `../arr/movie pipe.md`), tv через iptv simple.
Файл описывает, из чего теперь состоит каталог, что и почему поменялось в
рефакторе и что осталось нерешённым.

## Раскладка

| Файл | Что |
| --- | --- |
| `default.nix` | модуль: пакет, источники библиотеки, импорт `userdata.nix` |
| `package.nix` | kodi + аддоны, `addonIds`, необязательная обёртка с xray-прокси |
| `addons.nix` | сами аддоны: majan, tmdb helper, moviepipe, iptv simple, youtube |
| `userdata.nix` | всё, что kodi читает в `userdata`, и активация home-manager |
| `userdata.py` | `enable` / `defaults`: включить аддоны и первые настройки |
| `majan.nix` | сборка скина: `buildKodiAddon` + вызов патчера |
| `majan-patches.nix` | правки скина как данные (+ шрифт) |
| `majan-patch.py` | применяет `majan-patches.nix` к скину |
| `keyboard.xml` | vim-клавиши |
| `advancedsettings.xml` | имена торрентов для скрапера, аниме без сезона |
| `majan-moviepipe.xml` | страница фильма majan с кнопками movie pipe |
| `moviepipe-bars.py` | текстуры прогресс-баров и подчёркивания для аддона |
| `moviepipe/` | сам аддон: `plugin.video.moviepipe` |

## Что изменено и почему

### 1. `default.nix` разбит на три файла

Было 173 строки, в которых лежали сборка пакета, tv-каналы, генерация
userdata и активация. Стало: модуль (44 строки), пакет, userdata.

Причины:

- модуль читается сверху вниз как «что включено», а не как рецепт сборки;
- `useProxy` и обёртка над kodi больше не мешают читать настройки;
- внутри старого файла `lib` перекрывался: снаружи nixpkgs'ный, внутри
  home-manager'овский. Теперь `lib` — всегда home-manager'овский в
  `userdata.nix`, а `package.nix` packages-функция без `config`.

`package.nix` — функция `{ pkgs, inputs }`, возвращает `{ package,
addonIds }`. `addonIds` берётся из `requiredKodiAddons` тех же аддонов, что
попали в `withPackages`, так что список для включения не может разойтись с
установленным.

### 2. `defaults.py` + `enable-addons.py` → `userdata.py`

Два скрипта делали одно и то же: лезли в `~/.kodi` на активации. Теперь
один файл и две подкоманды:

```
userdata.py enable  DATADIR ID...
userdata.py defaults DATADIR /nix/store/...-kodi-defaults.json
```

Помимо дедупликации (`running()`, выход с сообщением, общий `datadir`):

- `enable` больше не валит `home-manager switch`. Раньше `sqlite3` на базе
  аддонов, которую держит запущенный kodi, бросал исключение, и активация
  падала. Теперь это warning в stderr и код 0 — база обновится на
  следующем переключении.
- у `id` в цикле больше нет затенения builtin'а;
- `max(found, key=..., default=None)` вместо `if not dbs / max(...)`;
- `attrs` пишутся через `lib.escapeShellArgs`, а не склейкой через пробел.

### 3. `majan.nix`: правки скина стали данными

Было ~90 строк `substituteInPlace` вперемешку с `sed`/`awk` и почти без
`--replace-fail`. Стало: `majan-patches.nix` (список правок) и
`majan-patch.py` (применение).

Почему это важно:

- `substituteInPlace` без `--replace-fail` **молча** ничего не делает, если
  строка уехала после обновления скина: скин собирается, а правки нет;
- `substituteInPlace` **заменяет все** вхождения в файле. Часть правок
  должна бить ровно в одно место, часть — во все (`<top>202</top>` — 6: три
  бокса заголовка спотлайта на разные кегли и три невидимые пробы, которые
  меряют, сколько строк вышло). Раньше это было неявно и держалось на удаче.

Теперь у каждой правки есть `file`, `from`, `to` и число вхождений:
`count` по умолчанию 1, для «все намеренно» — проставленное число (2, 6, 3).
Любое расхождение — ошибка сборки с файлом и текстом:

```
majan: 1080i/Includes_Home.xml: 5 of '<top>202</top>', wanted 6
```

Плюс после всех правок каждый затронутый файл парсится `xml.etree`:
патч, который разрезал тег (например, вставил `<include>` внутрь
атрибута), — ошибка сборки, а не «kodi молча не грузит окно».

Шрифтовой блок (второй fontset «JetBrains Mono») перенесён из
`sed -n | sed | awk` в питон. Правило прежнее: берём `Default`, меняем
`HankenGrotesk-` и `MajanDisplay-ExtraBold` на `JetBrainsMonoNLNerdFont-`,
размеры умножаем на 0.88 (`int(n * 0.88 + 0.5)`, как делал `awk`), вставляем
перед `</fonts>`.

Ревизия скина не запинена: обновление `kodi-skins` проходит, если он не
тронул нужные строки, и падает с точным сообщением, если тронул. Жёсткий
пин требовал бы править nix на каждый `nix flake update`.

### 4. `keyboard.xml`: нельзя было набрать цифры

`<one>`…`<six>` в `<global>` открывают страницы majan (tv, tmdb helper,
закачки) **во всех окнах**, включая экранную клавиатуру. Поиск «1917»,
«Blade Runner 2049», «Дюна 2» — цифра вместо символа переключала страницу.

Добавлены `zero`…`nine` → `noop` в `<VirtualKeyboard>`, рядом с уже
имевшимися `h/j/k/l/g/q/f//`. `noop` отдаёт клавишу окну, окно печатает
символ.

### 5. moviepipe: прогресс-бар и торренты

- `windows.row()`: `percent` считался как `100 * (size - left) / size` без
  границ. У сезонного пака sonarr `sizeleft` больше `size`, получалось
  `-20 %`, у разгона — `105 %`; файла `bars/-20.png` нет, полоска исчезала.
  Теперь `max(0, min(100, ...))`.
- `windows.downloads()`: торрент из qBittorrent искался только по `hash`.
  В qBittorrent 5 у части торрентов v1-хеш лежит в `infohash_v1`, и строка
  оставалась без скорости, сидов, ETA и кнопки паузы. Теперь индексируются
  оба поля.
- `show_downloads()` больше не ждёт lock после закрытия окна. Раньше `esc`
  во время обновления (radarr + sonarr + qBittorrent, до 10 с каждый)
  блокировал UI-поток kodi до 30 с. Теперь `done.set()` и выход: поток
  видит флаг сразу после запросов и к окну не притрагивается.

### 6. moviepipe: сервис не умирает и не держит kodi

`service.py` каждую минуту читает историю radarr/sonarr и сканирует папки в
библиотеку.

- **Падения.** Было `r["date"]`, `r["quality"]["quality"]["name"]`,
  `r["movie"]["path"]` — один неожиданный/пустой ответ, и исключение
  выходило из цикла: сервис молча умирал до перезапуска kodi (пропадали и
  уведомления, и автоскан). Теперь `parse()` возвращает `None` на мусор,
  `quality()`/`folder()` читают через `.get`, записи без даты
  пропускаются, а тело цикла обёрнуто в `try/except` с записью в лог kodi.
- **Выход из kodi.** Запросы шли в основном потоке скрипта, а kodi ждёт
  этот поток при выходе; мёртвый radarr (таймаут 60 с) задерживал
  завершение. Теперь запросы в daemon-потоке (`Service`), основной поток
  только ждёт abort, таймаут истории 60 → 20 с.

### 7. moviepipe: мелочи

- `person.py`: `setFocusId()` из рабочего потока заменён на
  `xbmc.executebuiltin("SetFocus(...)")` — биндинг выполняется в UI-потоке;
  `getControl(ROW).selectItem(0)` в `try/except RuntimeError` (поток может
  доработать после закрытия окна); переменная цикла больше не затеняет
  параметр `tab`.
- `addons.nix`: версия аддона читается из его собственного `addon.xml`
  (`addonVersion`). Kodi показывает версию из `addon.xml`, деривация —
  свою; теперь они не могут разойтись.

### 8. Настройки tmdb helper объявлены в nix

`players()` в `service.py` каждый старт kodi дёргала `setSettingBool` /
`setSettingInt`. Теперь это `programs.kodi.addonSettings`:

- `only_resolve_strm = "true"` — tmdb helper играет секунду своего
  `dummy.mp4` перед плеером, который не файл; файлы уходят в mpv, значит
  dummy нужен только `.strm`;
- `pagemulti_sync = "3"` — списки фильмов персоны по 60 на страницу вместо
  20 (см. `moviepipe/person.py`).

Цена: `addon_data/plugin.video.themoviedb.helper/settings.xml` — симлинк в
store, и остальные настройки tmdb helper, изменённые из GUI, после
перезапуска не сохранятся. Если это начнёт мешать — убрать блок из
`userdata.nix` и вернуть `players()`.

## Что осталось нерешённым

### Кавычки в имени файла и внешний плеер mpv

`playercorefactory.xml` отдаёт видео внешнему плееру. Kodi подставляет путь
в строку без экранирования и запускает её через `system()`
(`xbmc/cores/ExternalPlayer/ExternalPlayer.cpp`: `StringUtils::Replace(...,
"{1}", mainFile)` и `system(strSwitches)`). Поэтому `"`, `$`, `` ` `` и `\`
в имени файла ломают команду при любом `<args>`. У radarr/sonarr такие имена
практически не встречаются; чинится только заменой ExternalPlayer на
плагин-резолвер, который сам вызывает `exec [mpv, path]` (kodi тогда считает
«плеером» фиктивный элемент, это отдельная задача).

### Русские строки в moviepipe

Строки аддона английские намеренно (коммит «movie pipe in English»), и в
системе установлен только `resource.language.en_gb`. Перевод имеет смысл
только вместе с русским языком в самом kodi: `strings.po` в
`resources/language/resource.language.ru_ru/`, `getLocalizedString` в питоне
и `$LOCALIZE[]` в xml окон.

## Как проверить

```sh
# скин собирается и совпадает с прежним результатом
nix eval --raw .#nixosConfigurations.barnard.config.home-manager.users.barnard.programs.kodi.package.drvPath
nix-store --realise <drv>

# активация на «чистом» kodi (временный datadir)
python3 nixos/services/kodi/userdata.py defaults /tmp/kodi <kodi-defaults.json>
python3 nixos/services/kodi/userdata.py enable /tmp/kodi skin.majan pvr.iptvsimple

# правки скина
python3 nixos/services/kodi/majan-patch.py <skin> <patches.json> <fonts>
```

Проверено при рефакторе:

- собранный `skin.majan` побайтово совпадает со скином до рефакторинга;
- дерево аддонов в `kodi-env` совпадает с прежним;
- `userdata.py` прогнан на пустом datadir, на существующем
  `guisettings.xml` (с `default="true"` и без) и на поддельной
  `Addons33.db`;
- `service.poll()` прогнан на подставном API: уведомления, дедупликация по
  `downloadId`, папка в очередь скана, запись без даты не роняет сервис;
- `nixosConfigurations.barnard.config.system.build.toplevel` эвалится.
