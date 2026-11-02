return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	opts = {
		-- over 1.5 MB: no treesitter, lsp, matchparen. regex syntax stays
		bigfile = { enabled = true },
		dashboard = {
			enabled = true,
			width = 24,

			preset = {
				keys = {
					{
						key = "g",
						desc = "find text",
						action = function()
							require("util.pick").grep()
						end,
					},
					{
						key = "r",
						desc = "recent files",
						action = function()
							require("util.pick").recent()
						end,
					},
					{
						key = "f",
						desc = "find file",
						action = function()
							require("util.pick").files()
						end,
					},
					{
						key = "p",
						desc = "projects",
						action = function()
							require("util.pick").projects()
						end,
					},
					{ key = "q", desc = "quit", action = ":qa" },
				},
			},

			formats = {
				key = { "%s", hl = "SnacksDashboardKey" },
				desc = { "%s", hl = "SnacksDashboardDesc" },
			},

			sections = {
				{
					section = "keys",
					gap = 0,
					padding = 0,
				},
			},
		},
	},

	init = function()
		vim.api.nvim_set_hl(0, "SnacksDashboardNormal", { fg = "#ebdbb2", bg = "NONE" })
		vim.api.nvim_set_hl(0, "SnacksDashboardKey", { fg = "#d65d0e", bold = true })
		vim.api.nvim_set_hl(0, "SnacksDashboardDesc", { fg = "#928374" })
		vim.api.nvim_set_hl(0, "SnacksDashboardSpecial", { fg = "#a89984" })
	end,
}
