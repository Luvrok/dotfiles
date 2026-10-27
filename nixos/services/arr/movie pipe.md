---
tags: [nixos, kodi, barnard]
---

# Movie pipe

Фильмы и сериалы на barnard: нашёл в Kodi → нажал «Скачать» → через какое-то время фильм лежит в библиотеке с русскими субтитрами рядом, Kodi сам его отсканировал. Всё настроено декларативно в dotfiles, ничего не нужно настраивать руками в веб-интерфейсах.

```mermaid
flowchart LR
  K[Kodi<br>TMDb Helper] -- "Enter или c → Скачать /<br>Выбрать раздачу…" --> R[Radarr / Sonarr]
  R -- поиск --> P[Prowlarr]
  P --> T2[uindex] & T3[thepiratebay] & T4[1337x]
  P -. Cloudflare .-> F[FlareSolverr]
  P --> RP[rutracker-proxy] --> T1[rutracker]
  RP -. кука .-> F
  R -- торрент --> Q[qBittorrent<br>без GUI]
  Q -- "/media/outer-1/downloads" --> R
  R -- "хардлинк, переименование" --> L["/media/outer-1/movies, series"]
  L --> B[Bazarr]
  B -- ".ru.srt / .en.srt" --> L
  B -- "английские, если нет русских" --> S[subtitles.py] --> J[subtitle-translator<br>на jedha] --> L
  L -- "скан папки" --> K
```

## Что где

| Что | Где | Зачем |
|---|---|---|
| qBittorrent (headless) | http://127.0.0.1:8140 | качает торренты Radarr/Sonarr, без логина с этой машины. GUI-qBittorrent не трогается |
| Radarr | http://127.0.0.1:7878 | фильмы: ищет, выбирает раздачу, переносит в `movies` |
| Sonarr | http://127.0.0.1:8989 | сериалы, то же для `series` |
| Prowlarr | http://127.0.0.1:9696 | трекеры, отдаёт их Radarr и Sonarr |
| Bazarr | http://127.0.0.1:6767 | субтитры ru и en |
| FlareSolverr | 127.0.0.1:8191 | проходит проверку Cloudflare («Just a moment…») для 1337x и uindex, даёт куку rutracker-proxy |
| rutracker-proxy | 127.0.0.1:8150 | rutracker через Cloudflare: [rutracker-cf-proxy](https://github.com/rofl3228/rutracker-cf-proxy), в Prowlarr — «RuTracker» |

Все веб-интерфейсы только на `127.0.0.1`, снаружи их не видно. В файрволе открыт только порт пиров qBittorrent (51413 TCP/UDP).

Код:

- `nixos/services/arr/default.nix` — сервисы
- `nixos/services/arr/setup.py` — настройка через их API (сервис `arr-setup`, на каждой загрузке и switch)
- `nixos/services/arr/subtitles.py` — перевод субтитров
- `nixos/services/arr/shared.nix` — порты и пути
- `nixos/services/kodi/moviepipe/` — аддон Kodi «Movie pipe»
- `nixos/services/kodi/addons.nix` — все аддоны Kodi

## Один раз: логины

Логины лежат в `secrets/arr.yaml` (sops, как остальные секреты). Все необязательные: без файла пайплайн работает, просто без rutracker, opensubtitles.com и перевода.

```sh
sops secrets/arr.yaml
```

```yaml
rutracker_username: логин
rutracker_password: пароль
# бесплатный аккаунт opensubtitles.com, там большинство русских субтитров
opensubtitles_username: логин
opensubtitles_password: пароль
# ключ LibreTranslate на jedha, тот же, что вводишь на странице subtitle-translator
libretranslate_key: ключ
```

```sh
git add secrets/arr.yaml   # flake видит только файлы в git
sudo nixos-rebuild switch --flake .#barnard
```

После смены файла `arr-setup` перезапускается сам и вписывает логины в Prowlarr и Bazarr.

> [!note] RuTracker
> rutracker закрыт проверкой Cloudflare, туда ходит `rutracker-proxy` (кука от FlareSolverr, запросы как от того же Chrome). Если сам rutracker попросит капчу при входе, Prowlarr покажет её картинкой в Indexers → RuTracker → Test. Или войди один раз на rutracker в браузере с barnard.

## Каждый день

### Найти и скачать

- `5` — TMDb Helper: поиск, популярное, актёры, фильмография режиссёра, похожие.
- Enter на фильме или серии в TMDb Helper — выбор: **Movie pipe: Выбрать раздачу…** или **Movie pipe: Скачать** (у фильма из библиотеки там же «Play with Kodi»). Перед списком на секунду мелькает чёрный экран — так TMDb Helper запускает свои плееры.
- На фильме, сериале, сезоне или серии `c` → **Скачать**: Radarr/Sonarr сами найдут лучшую раздачу и скачают.
  - сериал — спросит, какие сезоны (по умолчанию все);
  - сезон или серия в TMDb Helper — качает именно их.
- `c` → **Выбрать раздачу…** — список раздач со всех трекеров, лучшие сверху, вторая строка: качество · размер · сиды · трекер · `RU` если есть русский звук. Помеченные `✗` Radarr сам бы не взял (почему — написано), но выбрать можно любую. Если ничего не выбрал — фильм не добавляется.
- `6` — что качается: процент, сколько осталось, ошибки. Enter на загрузке: **Другая раздача** (эта в чёрный список, ищет следующую) или **Убрать загрузку**.

Kodi показывает уведомления: «Качаю…», «Скачано…», «Не скачалось…». Когда фильм перенесён в библиотеку, Kodi сканирует только его папку — фильм появляется сам. Если Kodi был выключен, он догонит при запуске.

Пункты меню есть на фильмах не из библиотеки и на любых сериалах (в том числе из библиотеки — докачать новый сезон).

### Какие раздачи берутся

Профиль качества **BDRip 1080p** (Radarr и Sonarr):

1. Bluray-1080p (BDRip) — лучший
2. WEB-DL / WEBRip 1080p
3. 720p — только если 1080p нет; потом заменится на 1080p, когда появится
4. Remux, 4K, BR-DISK, CAM — не берутся автоматически

Среди одинаковых по качеству выигрывает русская озвучка (+10 к оценке), потом трекер по приоритету: rutracker → uindex → thepiratebay → 1337x, потом больше сидов. Скачанный WEB-DL 1080p уже не меняется на BDRip.

Имена: `Фильм (2010) {tmdb-27205} [Bluray-1080p].mkv`, сериалы `Сериал (2008) {tmdb-1396}/Season 01/Сериал - S01E01 - Название [WEBDL-1080p].mkv`. `{tmdb-…}` Kodi читает и находит точный фильм на TMDb без поиска по названию.

### Раздача и место

Торренты качаются в `/media/outer-1/downloads`, в библиотеку попадают хардлинками — место не удваивается, раздача продолжается. До рейтинга 2 или 30 дней, потом qBittorrent останавливает торрент, Radarr/Sonarr его удаляют из `downloads`. В библиотеке файл остаётся.

## Субтитры

Bazarr ищет для каждого нового фильма и серии **русские и английские** (профиль «Russian, English»). Русские не ищутся, если в видео есть русская дорожка.

Провайдеры: opensubtitles.com (нужен аккаунт), YIFY (фильмы), TVsubtitles (сериалы), embeddedsubtitles — достаёт дорожки субтитров из самого видео в отдельный файл.

Перевод (`subtitles.py`):

1. Bazarr скачал английские → кладёт их в очередь `/var/lib/arr/subtitles`.
2. Через 2 минуты (Bazarr за это время успевает найти русские, если они есть) проверка: есть ли рядом `.ru.srt`, русская дорожка или русские субтитры внутри видео. Есть — ничего не делает.
3. Нет — отправляет английские на subtitle-translator jedha (LibreTranslate): сначала через `jedha-tunnel` (`127.0.0.1:5390`), если не отвечает — через `lt.vxrnt.ru`.
4. Результат кладёт рядом с видео как `Фильм….ru.srt`. mpv подхватывает его сам.

Файлы по одному, сезон сериала переводится по серии. Ошибка (jedha выключен) — повтор через 30 мин, 1 ч, 2 ч… всего 6 попыток. Переведённые Bazarr считает русскими и больше русские для этого видео не ищет.

## Прокси

Radarr, Sonarr, Prowlarr и Bazarr ходят в интернет через xray (`127.0.0.1:10808`), qBittorrent — никогда; напрямую только локальная сеть и `127.0.0.1`. Причина: серверы Prowlarr (описания трекеров, проверка FlareSolverr), Radarr и Sonarr стоят за Cloudflare, а провайдер его режет — напрямую Prowlarr не мог скачать описания uindex, TPB и 1337x. Пока xray выключен, поиск не работает. Выключить: `useProxy = false;` в `nixos/services/arr/default.nix`. Для самого Kodi (постеры TMDb) — свой `useProxy` в `nixos/services/kodi/default.nix`.

## ТВ

`4` — каналы. Списки бесплатных каналов iptv-org: «Россия» (Первый, Россия 1, НТВ и другие) и «News» (новости со всего мира: LiveNOW from FOX, CBS News, Bloomberg, Sky News, DW…). Сам Fox News Channel платный, бесплатно его нет. ТВ и стримы играют во встроенном плеере Kodi, файлы библиотеки — в mpv.

Списки задаются в `nixos/services/kodi/default.nix` (`channels`), в Kodi они пишутся один раз; потом их можно менять в настройках IPTV Simple Client прямо в Kodi.

## Звуки и вид

Из скинов остался только Majan, шрифт JetBrains Mono (с кириллицей). Ставится само, пока в Kodi стоит значение по умолчанию; если Kodi был открыт во время switch — со следующего switch. Своих звуков нет, их выбирают в Kodi: Settings → Interface → Skin → Navigation sounds (например, Titan). Шрифт там же, Fonts.

## Если что-то не так

```sh
systemctl status arr-setup radarr sonarr prowlarr bazarr qbittorrent flaresolverr
journalctl -u arr-setup -b       # что настроилось, что нет; при ошибке сам повторит через 30 мин
journalctl -u arr-subtitles -f   # перевод субтитров
ls /var/lib/arr/subtitles        # очередь перевода
journalctl -u radarr -f          # поиск и импорт фильмов
```

- Ничего не находит — Prowlarr → Indexers → Test all. Красные 1337x/uindex — FlareSolverr (`journalctl -u flaresolverr`); всё красное — xray (v2rayN) выключен.
- Красный RuTracker — `curl -s 127.0.0.1:8150/health` (есть ли кука Cloudflare, `last_error`) и `journalctl -u rutracker-proxy`. Капчу на входе Prowlarr показывает картинкой: Indexers → RuTracker → Test, ввести код. Или один раз войти на rutracker в браузере с barnard.
- Скачалось, но нет в Kodi — Radarr → Activity → Queue (ошибка импорта), или `f` в Kodi.
- Нет субтитров — Bazarr → Wanted / History.
- Переводчик: `curl -s http://127.0.0.1:5390/subtitle-translator/api/languages` должен вернуть список языков. `LibreTranslate unreachable` — на jedha лежит LibreTranslate (`systemctl status libretranslate`).
- Настройки из веб-интерфейсов не трогаются, кроме тех, что задаёт `setup.py` (профиль, клиент загрузок, именование, трекеры, языки Bazarr) — их он вернёт на следующем запуске.
