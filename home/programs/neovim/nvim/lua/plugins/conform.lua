return {
	"stevearc/conform.nvim",
	event = {
		"BufReadPre",
		"BufNewFile",
	},
	opts = {
		notify_on_error = false,
		format_on_save = function()
			return {
				timeout_ms = 500,
				lsp_fallback = true,
			}
		end,
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
}
