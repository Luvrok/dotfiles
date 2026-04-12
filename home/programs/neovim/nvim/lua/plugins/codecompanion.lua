return {
	"olimorris/codecompanion.nvim",
	version = "^18.0.0",
	enabled = false,
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
	opts = {
		adapters = {
			http = {
				ollama = function()
					return require("codecompanion.adapters").extend("ollama", {
						env = {
							url = "http://localhost:11434",
						},
						schema = {
							model = {
								default = "gpt-oss:latest",
							},
						},
					})
				end,
			},
		},
		interactions = {
			chat = {
				adapter = "ollama",
			},
			inline = {
				adapter = "ollama",
			},
		},
		display = {
			chat = {
				fold_reasoning = false,
				show_reasoning = false,
				show_token_count = false,
			},
		},
	},
	keys = {
		{
			"<leader>at",
			function()
				require("codecompanion").toggle({ window_opts = { layout = "float", width = 0.8 } })
			end,
			mode = { "n", "x" },
			desc = "Toggle codecompanion chat",
		},
		{
			"<leader>aa",
			":CodeCompanionActions<CR>",
			mode = { "n", "x" },
			desc = "Open codecompanion actions",
		},
		{
			"<leader>as",
			":CodeCompanion<CR>",
			mode = { "n", "x" },
			desc = "Ask codecompanion",
		},
	},
}
