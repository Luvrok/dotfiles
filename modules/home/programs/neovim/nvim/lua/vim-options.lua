vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- UI and behavior
vim.o.number = true
vim.o.mouse = "a"
vim.o.showmode = false

vim.schedule(function()
	vim.o.clipboard = "unnamedplus"
end)

vim.o.breakindent = true
vim.o.undofile = true
vim.o.ignorecase = true
vim.o.smartcase = true
vim.o.signcolumn = "yes"
vim.o.background = "dark"
vim.o.updatetime = 250
vim.o.timeoutlen = 300
vim.o.splitright = true
vim.o.splitbelow = true
vim.o.list = true
vim.opt.listchars = { tab = "  ", trail = "·", nbsp = "␣" }
vim.o.inccommand = "split"
vim.o.cursorline = true
-- vim.opt.cursorcolumn = true
vim.o.scrolloff = 10
vim.o.confirm = true
vim.opt.swapfile = false
vim.opt.laststatus = 3 -- чтобы статусбар был общий (красивее)
vim.opt.wrap = true

-- tabs
vim.opt.expandtab = true
vim.opt.shiftwidth = 2
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.smartindent = true
vim.opt.autoindent = true

vim.wo.relativenumber = true

-- disable search, dont like it
vim.opt.hlsearch = false
vim.opt.incsearch = false

-- sway scripts have no shebang (writeShellApplication adds it), without this
-- they open as conf: no bash highlighting, no bashls, no shellcheck
vim.filetype.add({
	pattern = {
		[".*/dotfiles/nixos/services/sway/scripts/.*"] = "bash",
		[".*/dotfiles/nixos/services/hyprland/quickshell/scripts/.*"] = "bash",
	},
})
