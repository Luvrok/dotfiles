return {
	"nvim-lualine/lualine.nvim",
	event = "VeryLazy",
	config = function()
		require("lualine").setup({
			options = {
				icons_enabled = false,
				theme = "gruvbox",
				component_separators = { left = "", right = "" },
				section_separators = { left = "", right = "" },
			},
			sections = {
				lualine_x = { "filetype" },
			},
		})
	end,
}
