vim.g.loaded_netrw = 1
vim.g.loaded_netrwPlugin = 1

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	local out = vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--branch=stable",
		"https://github.com/folke/lazy.nvim.git",
		lazypath,
	})
	if vim.v.shell_error ~= 0 then
		vim.api.nvim_echo({
			{ "Failed to clone lazy.nvim:\n", "ErrorMsg" },
			{ out, "WarningMsg" },
			{ "\nPress any key to exit..." },
		}, true, {})
		vim.fn.getchar()
		os.exit(1)
	end
end
vim.opt.rtp:prepend(lazypath)

require("vim-options")

-- the plugin versions are part of this config (lazy-lock.json next to this
-- file), so a copy of the config installs the same plugins. on nixos
-- ~/.config/nvim is a read-only store link: `:Lazy update` writes the repo's
-- copy, which is what the next switch deploys
local function lockfile()
	local repo = vim.env.HOME .. "/HOME/infra/dotfiles/modules/home/programs/neovim/nvim/lazy-lock.json"
	if vim.uv.fs_stat(repo) then
		return repo
	end
	return vim.fn.stdpath("config") .. "/lazy-lock.json"
end

require("lazy").setup("plugins", {
	-- no plugin here needs luarocks
	rocks = { enabled = false },
	-- the config is a store link, it changes only with a switch
	change_detection = { enabled = false },
	lockfile = lockfile(),
	install = { colorscheme = { "gruvbox" } },
})
require("lsp")
require("keymaps")
require("autocmds")
