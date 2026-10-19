# Neovim: рефакторинг LSP, treesitter, blink

Цель: LSP подключены надёжно, treesitter работает по всем языкам, которые
реально редактируются, blink настроен явно. Конфиг стал короче (−93 строки),
keybinds те же. К `<Tab>` добавился прыжок по сниппету.

Проверено вживую:

- окружение: nvim 0.12.6, nixd 2.9.3, gopls 0.23.0, lua-language-server 3.19.2,
  bash-language-server 5.8.1 + shellcheck 0.11 (всё из nixos-unstable), плагины с HEAD;
- метод: headless nvim, ввод через `--remote-send`, состояние через `luaeval`, плюс `:checkhealth`.

## Сделано

### LSP (`lua/lsp.lua`, `lua/plugins/lspconfig.lua`)

- **Конфиги серверов берутся из nvim-lspconfig.** Плагин даёт только файлы `lsp/<name>.lua`,
  `setup()` не вызывается. В `lsp.lua` остались только отличия от дефолтов: 239 → 123 строки.
- **Новые имена серверов** (lspconfig):
  `bash-language-server` → `bashls`, `typescript-language-server` → `ts_ls`,
  `vscode-html/css/json-language-server` → `html`/`cssls`/`jsonls`,
  `yaml-language-server` → `yamlls`.
- **Убрано лишнее:**
  - 15× `capabilities = capabilities`: blink сам ставит их на `vim.lsp.config("*")`;
  - `single_file_support`: опция старого lspconfig, `vim.lsp.config` её игнорирует.
- **eslint удалён.** Он запускался без settings/handlers и всегда отдавал 0 диагностик.
- **nixd:**
  - путь до флейка = `$HOME/HOME/infra/dotfiles`;
  - имя конфигурации = hostname. Раньше было захардкожено `barnard`, теперь `dash` тоже
    получает дополнение опций и `pkgs.`;
  - убран мёртвый дубль `formatting`;
  - `--log=error`: раньше nixd писал каждый запрос в `lsp.log` с уровнем ERROR.
- **lua_ls:**
  - `runtime = LuaJIT`;
  - `library = { $VIMRUNTIME }` вместо всех runtime-путей (раньше брались только плагины,
    загруженные к моменту `require("lsp")`, и для любого Lua-проекта);
  - лишний global `require` убран.
- **gopls:** убраны `-tags=amd64` (это GOARCH, а не тег) и `GOOS=linux` (на Linux ничего не
  меняет). `shadow` оставлен как был.
- **bashls:** shellcheck с `--exclude=SC2016`, как в `writeShellApplication`.
- **Диагностика:** `vim.diagnostic.config` с `severity_sort = true` и общими настройками float.
  Float на CursorHold как раньше.

### blink (`lua/plugins/blink-cmp.lua`)

- **`lazy = false` вместо `VeryLazy`.** Раньше правильная загрузка держалась на случайном
  `require` в `lsp.lua`.
- **`<Tab>` = accept → snippet_forward → fallback.** Проверено на сниппете lua_ls
  `vim.keymap.set(modes, lhs, …)`: Tab принимает, следующий Tab прыгает к `lhs`.
- **Клавиши выписаны явно, `preset = "none"`.** Раньше стоял `preset = "enter"`, а `<CR>` тут же
  отключался. Остались твои клавиши и полезные из пресета: `<S-Tab>`, `<C-b>`/`<C-f>`, `<C-k>`.
  `<CR>` теперь не трогает blink и сразу уходит в mini.pairs.
- **Убран мёртвый `kind_icon`.**
- **`fuzzy = "prefer_rust"`.** Сортировка лучше, если бинарь не скачается — тихо уходит на lua.
  В тесте `fmt.Pri` теперь сначала даёт `Println`.
- **Режим «только ghost text» оставлен как был.** Меню открывается по `<C-space>`.

### Treesitter (`lua/plugins/treesitter.lua`, `gruvbox.lua`, `snacks.lua`)

- **Новые парсеры:** `yuck` (eww.yuck раньше был вообще без подсветки), `rasi`, `zsh`,
  `gomod`/`gosum`/`gowork`, `cpp`, `sql`, `python`, `rust`, `make`, `dockerfile`, git-форматы,
  `comment`. Убран `clojure`.
- **FileType-autocmd** стартует TS, только если для языка есть парсер, без глухого `pcall`.
- **Большие файлы:** порог 200 KB заменён на `snacks.bigfile` (1.5 MB, отключает TS, LSP и matchparen).
- **gruvbox:** мёртвые переопределения переименованы на актуальные группы:
  `@conditional`, `@repeat`, `@method*`, `@field` → `@keyword.conditional`,
  `@keyword.repeat`, `@function.method*`, `@variable.member`. Теперь ключи атрибутов в nix,
  `if/for` в go и методы реально получают твои цвета.

### Отступы и filetype

- **Отступы в nix.** Добавлен `LnL7/vim-nix` (`ft = "nix"`) ради `indent/nix.vim`. Раньше nvim
  не знал, как отступать в nix, и `smartindent` кидал каждый `# комментарий` в колонку 0.
  Проверено: `#`, `{ }`, `[ ]` отступают правильно.
- **i3-скрипты.** `home/scripts/*` (без shebang) теперь открываются как `bash`, а не `conf`.
  Включаются TS-подсветка, bashls и shellcheck.

### Мелочи

- В `keymaps.lua` объявлен `opts = { silent = true }`. Раньше это был nil-глобал в 16 маппингах.
- conform:
  - `lsp_fallback` → `lsp_format = "fallback"`;
  - Go: `goimports` + `gofumpt`;
  - добавлен filetype `bash`.
- Удалены `telescope-frecency` (ни один бинд его не вызывал) и `sqlite.lua` (frecency его не
  использует).
- `nixos/packages.nix`: добавлен `shellcheck`, убран неиспользуемый `nil`.
- `rocks = { enabled = false }` в lazy: больше нет ошибки luarocks в health.
- Дубли в options убраны (`cursorline`, `have_nerd_font`). Маппинги `n`/`N` переехали в `keymaps.lua`.

## После мержа

1. `sapply`, потом в nvim `:Lazy sync`. Он поставит nvim-lspconfig и vim-nix и удалит
   frecency и sqlite.lua. Новые парсеры treesitter соберутся сами (нужны `tree-sitter` и `gcc`,
   они есть).
2. `:checkhealth vim.lsp blink.cmp nvim-treesitter lazy`. Warning'и `Unknown filetype
   'c.doxygen'` и подобные идут из дефолтов lspconfig и безвредны.
3. На `dash` проверить, что `pkgs.` и `services.` дополняются.

## Не сделано (нужно твоё решение)

1. **Меню автодополнения.** Оставить «только ghost text» или показывать меню автоматически?
2. **Folds / nvim-ufo.** Ты пишешь, что не используешь их. Удалить ufo + promise-async
   (folds тогда через `vim.treesitter.foldexpr()`)? ⚠️ пропадёт `zk` (peek), `zR/zM/za/zo/zc`
   встроенные и останутся.
3. **Comment.nvim → встроенный `gc`.** `<C-/>` останется, но пропадут `gb*`, `gco/gcO/gcA`,
   которые Comment.nvim создаёт после первого нажатия.
4. **project.nvim.** Не обновлялся с 2023, использует deprecated API. Заменить на форк или
   аналог с тем же `<leader>o`?
5. **Симлинк на чекаут + `lazy-lock.json` в репо.** `~/.config/nvim` через `mkOutOfStoreSymlink`:
   правки без `sapply` и зафиксированные версии плагинов. Сейчас nvim-treesitter main и blink
   обновляются на каждый `:Lazy update`.
6. **telescope fzf `fuzzy = false`** (точное совпадение вместо нечёткого). Это специально?
7. **Format on save** для Go/Nix или оставить ручной `<leader>fm`?
8. **Остальные группы gruvbox.** `@keyword.import`, `@keyword.operator` и пути в nix
   (`@string.special.path`, сейчас подчёркнуты) берут цвета gruvbox. Покрасить в твою палитру?
9. **Инлайн-подсказки типов (inlay hints) для gopls/lua_ls.** Включить?

Отдельно: TS-indent (`nvim-treesitter.indent`) на nvim 0.12.6 + nvim-treesitter main HEAD
вернул 0 для nix и lua, поэтому я его не включал. Отступы для nix теперь даёт vim-nix.
