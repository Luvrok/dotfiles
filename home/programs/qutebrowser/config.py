config.load_autoconfig(False)

c.auto_save.session = True
c.auto_save.interval = 15000
c.fonts.web.family.fantasy = 'JetBrains Mono'
c.content.webrtc_ip_handling_policy = "default-public-interface-only"
c.content.geolocation = False
c.completion.height = "20%"
c.prompt.radius = 40
c.input.insert_mode.auto_load = True
c.input.insert_mode.auto_leave = True
c.downloads.position = "bottom"
c.window.transparent = True
c.completion.web_history.max_items = 20
c.completion.scrollbar.width = 18
c.content.cookies.accept = "all"
c.content.notifications.enabled = True
c.content.notifications.presenter = "libnotify"
c.content.pdfjs = True
c.content.tls.certificate_errors = "load-insecurely"
c.content.prefers_reduced_motion = True
c.statusbar.widgets = ["scroll", "progress", "keypress", "search_match", "url", "progress", "clock"]
c.statusbar.show = "always"
c.statusbar.position = "bottom"
c.logging.level.console = "error"

# Adblock
c.content.blocking.enabled = True
c.content.blocking.method = 'both'
c.content.blocking.adblock.lists = [
    'https://easylist.to/easylist/easylist.txt',
    'https://easylist.to/easylist/easyprivacy.txt',
    'https://secure.fanboy.co.nz/fanboy-annoyance.txt'
]

# Tabs
c.tabs.padding = {"top": 5, "bottom": 5, "left": 5, "right": 5}
c.tabs.title.format_pinned = c.tabs.title.format
c.tabs.position = "top"
c.tabs.pinned.shrink = False
c.tabs.new_position.related = "last"

# Keyboardio (TRY THESE WITH MY NEW KEYBOARDIO!!)
config.bind('<Shift-Left>', 'back')
config.bind('<Shift-Down>', 'tab-next')
config.bind('<Shift-Up>', 'tab-prev')
config.bind('<Shift-Right>', 'forward')

# Insert movement (Emacs style)
config.bind('<Ctrl+b>', 'fake-key <left>', 'insert')   # back
config.bind('<Ctrl+f>', 'fake-key <right>', 'insert')  # forward
config.bind('<Ctrl+p>', 'fake-key <up>', 'insert')     # previous line
config.bind('<Ctrl+n>', 'fake-key <down>', 'insert')   # next line

config.bind('<Ctrl+a>', 'fake-key <Home>', 'insert')   # beginning of line
config.bind('<Ctrl+e>', 'fake-key <End>', 'insert')    # end of line
config.bind('<Ctrl+d>', 'fake-key <Delete>', 'insert') # delete char
config.bind('<Alt+b>',  'fake-key <Ctrl-Left>', 'insert')  # back word
config.bind('<Alt+f>',  'fake-key <Ctrl-Right>', 'insert') # forward word

# Optional: submit + leave insert after Enter
config.bind('<Enter>', 'fake-key -g <enter>;; later 0.3s mode-leave', 'insert')

# Prompt editing (readline-style, Emacs-y)
config.bind('<Ctrl+a>', 'rl-beginning-of-line', 'prompt')
config.bind('<Ctrl+e>', 'rl-end-of-line', 'prompt')
config.bind('<Ctrl+b>', 'rl-backward-char', 'prompt')
config.bind('<Ctrl+f>', 'rl-forward-char', 'prompt')
config.bind('<Alt+b>',  'rl-backward-word', 'prompt')
config.bind('<Alt+f>',  'rl-forward-word', 'prompt')
config.bind('<Ctrl+d>', 'rl-delete-char', 'prompt')
config.bind('<Ctrl+h>', 'rl-backward-delete-char', 'prompt')
config.bind('<Ctrl+k>', 'rl-kill-line', 'prompt')
config.bind('<Ctrl+u>', 'rl-unix-line-discard', 'prompt')

# Completion navigation (like minibuffer candidates)
config.bind('<Ctrl+n>', 'prompt-item-focus next', 'prompt')
config.bind('<Ctrl+p>', 'prompt-item-focus prev', 'prompt')

# Move through :open / :history / command completions with Emacs keys
config.bind('<Ctrl-n>', 'completion-item-focus next',   'command')
config.bind('<Ctrl-p>', 'completion-item-focus prev',   'command')

# (optional) keep history on Alt+n / Alt+p
config.bind('<Alt-n>',  'command-history-next',         'command')
config.bind('<Alt-p>',  'command-history-prev',         'command')

# Toggle dark mode
config.bind(',d', "config-cycle colors.webpage.darkmode.enabled true false")

# Load theme (Keep all theme options at the bottom of this config.)
config.source('gruvbox.py')

# Tab bar background (behind all tabs)
c.colors.tabs.bar.bg = "#282828"   # gruvbox bg

# Active tab (selected)
c.colors.tabs.selected.odd.bg = "#d79921"   # muted gruvbox yellow
c.colors.tabs.selected.even.bg = "#d79921"
c.colors.tabs.selected.odd.fg = "#282828"   # dark text for contrast
c.colors.tabs.selected.even.fg = "#282828"

# Inactive tabs
c.colors.tabs.odd.bg = "#3c3836"   # gruvbox dark1
c.colors.tabs.even.bg = "#3c3836"
c.colors.tabs.odd.fg = "#bdae93"   # muted light fg
c.colors.tabs.even.fg = "#bdae93"

# Optional: indicator (loading line on tabs)
c.colors.tabs.indicator.start = "#d79921"
c.colors.tabs.indicator.stop = "#d79921"
c.colors.tabs.indicator.error = "#fb4934"   # gruvbox red
