vim.g.mapleader = " "
vim.g.maplocalleader = " "

local o = vim.opt

-- ui
o.number = true
-- absolute numbers, the cursor line is highlighted and the others don't move
o.relativenumber = false
o.cursorline = true
o.signcolumn = "yes"
o.showmode = false
o.laststatus = 3 -- one statusline for all windows
o.scrolloff = 10
o.wrap = true
o.breakindent = true
o.list = true
o.listchars = { tab = "  ", trail = "·", nbsp = "␣" }
o.background = "dark"

-- behavior
o.mouse = "a"
o.undofile = true
o.swapfile = false
o.confirm = true
o.splitright = true
o.splitbelow = true
o.updatetime = 250
o.timeoutlen = 300
o.inccommand = "split"

-- the clipboard provider is slow to load, after startup
vim.schedule(function()
	o.clipboard = "unnamedplus"
end)

-- search: case smart, no highlight while typing or after
o.ignorecase = true
o.smartcase = true
o.hlsearch = false
o.incsearch = false

-- indent: 2 spaces, indent-o-matic takes the file's own. indentexpr comes
-- from the filetype or treesitter (plugins/treesitter.lua)
o.expandtab = true
o.shiftwidth = 2
o.tabstop = 2
o.softtabstop = 2
o.autoindent = true

-- quickshell scripts have no shebang (writeShellApplication adds it), without this
-- they open as conf: no bash highlighting, no bashls, no shellcheck
vim.filetype.add({
	pattern = {
		[".*/dotfiles/modules/nixos/hyprland/quickshell/scripts/.*"] = "bash",
	},
})
