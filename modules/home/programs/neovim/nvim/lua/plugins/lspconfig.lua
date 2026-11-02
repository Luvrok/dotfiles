-- only the server configs (lsp/<name>.lua), lsp.lua enables them.
-- not lazy: vim.lsp.enable looks them up on the runtimepath
return {
	"neovim/nvim-lspconfig",
	lazy = false,
}
