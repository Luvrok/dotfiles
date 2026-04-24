return {
	"nvim-lualine/lualine.nvim",
	lazy = false,
	config = function()
		local colors = {
			accent = "#d65d0e",
			accent_soft = "#af3f05",
			accent_dim = "#8f3f1f",

			fg = "#ebdbb2",
			dim = "#928374",

			bg_l1 = "#121212",
			bg_l2 = "#202020",
			bg_l3 = "#282828",

			red = "#cc241d",
			green = "#98971a",
			yellow = "#d79921",
			blue = "#458588",
		}

		local theme = {
			normal = {
				a = { bg = colors.accent, fg = colors.fg },
				b = { bg = colors.bg_l3, fg = colors.fg },
				c = { bg = colors.bg_l2, fg = colors.fg },
			},

			insert = {
				a = { bg = colors.green, fg = colors.fg },
				b = { bg = colors.bg_l3, fg = colors.fg },
				c = { bg = colors.bg_l2, fg = colors.fg },
			},

			visual = {
				a = { bg = colors.yellow, fg = colors.fg },
				b = { bg = colors.bg_l2, fg = colors.fg },
				c = { bg = colors.bg_l1, fg = colors.fg },
			},

			command = {
				a = { bg = colors.bg_l3, fg = colors.fg },
				b = { bg = colors.bg_l2, fg = colors.fg },
				c = { bg = colors.bg_l1, fg = colors.fg },
			},

			replace = {
				a = { bg = colors.red, fg = colors.fg },
				b = { bg = colors.bg_l2, fg = colors.fg },
				c = { bg = colors.bg_l1, fg = colors.fg },
			},

			inactive = {
				a = { bg = colors.blue, fg = colors.fg },
				b = { bg = colors.bg_l2, fg = colors.fg },
				c = { bg = colors.bg_l1, fg = colors.fg },
			},
		}

		require("lualine").setup({
			options = {
				icons_enabled = false,
				theme = theme,
				component_separators = { left = "", right = "" },
				section_separators = { left = "", right = "" },
			},
			sections = {
				lualine_x = { "filetype" },
			},
		})
	end,
}
