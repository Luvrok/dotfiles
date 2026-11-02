return {
	"stevearc/conform.nvim",
	opts = {
		-- say why a format didn't happen (syntax error and the like)
		notify_on_error = true,
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
				-- async: no timeout. with a 500 ms one a cold prettierd never made it
				-- and the format was dropped without a word
				require("conform").format({
					async = true,
					lsp_format = "fallback",
				})
			end,
			desc = "Format buffer",
		},
	},
}
