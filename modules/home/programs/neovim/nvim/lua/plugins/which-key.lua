return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	opts = {
		spec = {
			{ "<leader>h", group = "git hunks" },
			{ "<leader>f", group = "format" },
			{ "<leader>l", group = "lazygit" },
			{ "<leader>i", group = "inlay hints" },
		},
	},
	keys = {
		{
			"<leader>?",
			function()
				require("which-key").show({ global = false })
			end,
			desc = "Buffer local keymaps",
		},
	},
}
