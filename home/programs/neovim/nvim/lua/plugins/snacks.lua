return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	opts = {
		bigfile = { enabled = false },
		dashboard = {
			enabled = true,
			width = 24,

			preset = {
				keys = {
					{
						key = "g",
						desc = "find text",
						action = function()
							require("telescope.builtin").live_grep({
								prompt_title = "search",
								results_title = "files",
								preview_title = "preview",
							})
						end,
					},
					{
						key = "r",
						desc = "recent files",
						action = function()
							require("telescope.builtin").oldfiles({
								prompt_title = "search",
								results_title = "files",
								preview_title = "preview",
							})
						end,
					},
					{
						key = "f",
						desc = "find file",
						action = function()
							require("telescope.builtin").find_files({
								prompt_title = "search",
								results_title = "files",
								preview_title = "preview",
							})
						end,
					},
					{
						key = "p",
						desc = "projects",
						action = function()
							require("telescope").extensions.projects.projects({
								prompt_title = "search",
								results_title = "projects",
								preview_title = "preview",
							})
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
