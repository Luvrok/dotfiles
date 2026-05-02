return {
	"ellisonleao/gruvbox.nvim",
	lazy = false,
	priority = 1000,
	opts = {
		contrast = "soft",
		overrides = {
			["@comment"] = { fg = "#928374", italic = false },
			["@keyword"] = { italic = false },
			["@parameter"] = { italic = false },
			["@type"] = { italic = false },

			SignColumn = { bg = "NONE" },
			TabLineFill = { bg = "#282828" },
			TabLineSel = { bg = "#282828" },
			CursorLine = { bg = "#282828" },

			NeoTreeDirectoryName = { fg = "#a89984" },
			NeoTreeRootName = { fg = "#d65d0e" },
			NeoTreeFileName = { fg = "#ebdbb2" },

			NeoTreeGitAdded = { fg = "#98971a" },
			NeoTreeGitConflict = { fg = "#b16286" },
      NeoTreeGitDeleted = { fg = "#cc241d" },
      NeoTreeGitIgnored = { fg = "#393939" },
      NeoTreeGitModified = { fg = "#d65d0e" },
      NeoTreeGitUntracked = { fg = "#d79921" },

			-- colorscheme
			-- "#fbf1c7", "#ebdbb2", "#d5c4a1", "#bdae93", "#a89984", "#928374", "#d65d0e", "#cc241d", "#98971a", "#458588", "#b16286", "#689d6a", "#d79921", "#fbf1c7"

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

		-- modicator
		vim.api.nvim_set_hl(0, "NormalMode", { fg = "#d65d0e" })
		vim.api.nvim_set_hl(0, "InsertMode", { fg = "#98971a" })
		vim.api.nvim_set_hl(0, "VisualMode", { fg = "#d79921" })

		vim.api.nvim_set_hl(0, "CommandMode", { fg = "#282828" })
		vim.api.nvim_set_hl(0, "ReplaceMode", { fg = "#cc241d" })
		vim.api.nvim_set_hl(0, "SelectMode", { fg = "#458588" })

		-- nvim-ufo (i dont use fold)
		-- vim.api.nvim_set_hl(0, "Folded", { bg = "NONE", fg = "#928374" })
		-- vim.api.nvim_set_hl(0, "FoldColumn", { bg = "NONE", fg = "#928374" })
	end,
}
