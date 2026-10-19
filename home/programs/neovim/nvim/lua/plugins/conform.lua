return {
	"stevearc/conform.nvim",
	opts = {
		notify_on_error = false,
		formatters_by_ft = {
			c = { "clang-format" },
			cpp = { "clang-format" },

			go = { "goimports", "gofumpt" },
			lua = { "stylua" },
			nix = { "nixfmt" },
			sql = { "sql_formatter" },
			typst = { "typstyle" },

			html = { "prettierd" },
			css = { "prettierd" },
			javascript = { "prettierd" },
			javascriptreact = { "prettierd" },
			typescript = { "prettierd" },
			typescriptreact = { "prettierd" },
			json = { "prettierd" },
			markdown = { "prettierd" },
			yaml = { "prettierd" },

			zsh = { "beautysh" },
			sh = { "beautysh" },
			bash = { "beautysh" },
		},
	},
	keys = {
		{
			"<leader>fm",
			function()
				require("conform").format({
					timeout_ms = 500,
					lsp_format = "fallback",
				})
			end,
			desc = "Format buffer",
		},
	},
}
