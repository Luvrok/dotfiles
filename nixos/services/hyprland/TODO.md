# hyprland: что осталось

Сделано в PR #6: меню утилит ($mod+a), эмодзи, калькулятор, превью картинок в буфере, микшер с проводами, уведомления, system/processes/calendar.

## quickshell, следующий PR

- **Плеер (MPRIS)**
  - В баре: трек и маленький визуализатор (cava, полоски в цветах темы), кнопка play/pause.
  - Меню плеера:
    - обложка, позиция, play/pause/next/prev;
    - список плееров (mpv, браузер);
    - визуализатор крупнее.
  - Клавиша `a` — в audio, из audio — обратно в плеер.
- **Скриншоты как flameshot**
  - Сначала кадр всего экрана (grim), выделение поверх замороженного кадра в окне Quickshell.
  - Инструменты, только основное: прямоугольник, стрелка, линия, текст, маркер, размытие, цвета из темы.
  - Скопировать или сохранить, `esc` — отмена.
  - Заменит плитку `s` в tools и бинд Print.
- **systemd** (плитка в tools)
  - Юниты user и system, сначала упавшие.
  - start/stop/restart/enable, хвост `journalctl` по юниту.
  - root через `sudo -A` (hypr-askpass).
- **Переключатели сервисов** (плитки со статусом)
  - xray, zapret, dnscrypt-proxy и прочее: вкл/выкл, статус в баре.
  - xray без v2rayN: перенести конфиг и routing (geosite:ru direct) из v2rayN в nix, сервис systemd.
  - Сначала посмотреть, что сейчас делает v2rayN.
- **proxychains-ng в Run**
  - Запуск любого приложения через xray (socks/http 127.0.0.1:10808), например `alt+enter`.
  - Go и статические бинарники мимо LD_PRELOAD: для них `HTTPS_PROXY` или отдельный netns/tun.
- **Переключатель окон**
  - Все окна со всех тегов с поиском.
  - Вкладки LibreWolf, как было в rofi: найти старый скрипт и расширение (native messaging), вернуть его в Quickshell.
- **Блокировка экрана** на Quickshell (`WlSessionLock`) в стиле меню, swayidle её вызывает.
- **Уведомления**
  - В меню группировать по приложению.
  - Быстрый ответ (inline reply, Telegram).

## hyprland

- **Обои видно при смене тега**
  - Причина: `slidefade` гасит оба тега сразу.
  - Попробовать живьём, без пересборки: старый тег не гаснет, новый проявляется поверх.
    ```sh
    hyprctl dispatch 'hl.animation({ leaf = "workspacesOut", enabled = true, speed = 2.5, bezier = "out", style = "slide 6%" })'
    ```
  - Если порядок окон даёт мигание — `style = "slide"` для обоих (сдвиг целиком, без прозрачности).
- **Фуллскрин без hide/show заднего фона**
  - Найти, какая анимация срабатывает у окон сзади.
  - Варианты: `no_anim` для них или фейковый фуллскрин (`fullscreen_state`) по классам, как у Telegram.
  - Качество mpv не падает, кадр тот же. Теряется только direct scanout: чуть больше нагрузка на GPU, VRR/tearing.
- **Тема VeraCrypt**
  - Это wxWidgets на GTK3, не Qt.
  - Проверить, как он запускается: под root не видит пользовательский dconf и `settings.ini`.
  - Для Qt-приложений в Hyprland: `QT_QPA_PLATFORMTHEME` (qt6ct/gtk3) плюс qt5ct/qt6ct или kvantum с gruvbox.

## отдельные PR

- **mpv:** конфиг под стиль шелла — OSC/uosc в gruvbox, шрифт, короткие понятные бинды.
- **LibreWolf:** textfox + sidebery под тему шелла.
