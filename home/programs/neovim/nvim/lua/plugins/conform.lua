return {
	"stevearc/conform.nvim",
	opts = {
		notify_on_error = false,
		formatters_by_ft = {
			c = { "clang-format" },
			cpp = { "clang-format" },

			go = { "gofumpt" },
			lua = { "stylua" },
			nix = { "nixfmt" },
			sql = { "sql_formatter" },

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
		},
	},
	keys = {
		{
			"<leader>fm",
			function()
				require("conform").format({
					timeout_ms = 500,
					lsp_fallback = true,
				})
			end,
			desc = "Format buffer",
		},
	},
}
