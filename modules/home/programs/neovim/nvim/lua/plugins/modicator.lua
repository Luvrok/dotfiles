-- the line number takes the mode's color (the highlights are in gruvbox.lua)
return {
	"mawkler/modicator.nvim",
	dependencies = "ellisonleao/gruvbox.nvim",
	opts = {
		show_warnings = true,
		highlights = {
			defaults = { bold = true, italic = false },
		},
		integration = {
			lualine = { enabled = true, highlight = "fg" },
		},
	},
}
