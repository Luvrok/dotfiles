return {
	"ellisonleao/gruvbox.nvim",
	lazy = false,
	priority = 1000,
	opts = {
		contrast = "soft",
		overrides = {
			["@comment"] = { italic = false },
			["@keyword"] = { italic = false },
			["@parameter"] = { italic = false },
			["@type"] = { italic = false },

			SignColumn = { bg = "#282828" },
			TabLineFill = { bg = "#282828" },
			TabLineSel = { bg = "#282828" },
			CursorLine = { bg = "#282828" },

			NeoTreeDirectoryName = { fg = "#928374", bold = true },
			NeoTreeRootName = { fg = "#d65d0e" },
			NeoTreeFileName = { fg = "#ebdbb2" },

			NeoTreeGitModified = { fg = "#d65d0e" },
			NeoTreeGitAdded = { fg = "#98971a" },
			NeoTreeGitUntracked = { fg = "#a89984" },
			NeoTreeGitDeleted = { fg = "#cc241d" },

			Visual = {
				bg = "#3c3836",
			},
		},
	},
	config = function(_, opts)
		require("gruvbox").setup(opts)
		vim.cmd("colorscheme gruvbox")

		vim.opt.fillchars:append({
			eob = " ",
			vert = " ",
		})

		vim.api.nvim_set_hl(0, "WinSeparator", { fg = "NONE", bg = "NONE" })
	end,
}
