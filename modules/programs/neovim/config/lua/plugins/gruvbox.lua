return {
	"ellisonleao/gruvbox.nvim",
	lazy = false,
	priority = 1000,
	opts = {
		contrast = "soft",
		overrides = {
			-- syntax
			["@comment"] = { fg = "#928374", italic = false },

			["@keyword"] = { fg = "#cc241d", italic = false },
			["@keyword.function"] = { fg = "#cc241d", italic = false },
			["@keyword.return"] = { fg = "#cc241d", italic = false },
			["@conditional"] = { fg = "#cc241d", italic = false },
			["@repeat"] = { fg = "#cc241d", italic = false },

			["@variable"] = { fg = "#ebdbb2" },
			["@variable.builtin"] = { fg = "#d65d0e" },
			["@variable.parameter"] = { fg = "#b16286", italic = false },
			["@parameter"] = { fg = "#b16286", italic = false },

			["@constant"] = { fg = "#b16286" },
			["@constant.builtin"] = { fg = "#d65d0e" },
			["@number"] = { fg = "#b16286" },
			["@boolean"] = { fg = "#b16286" },

			["@string"] = { fg = "#98971a" },
			["@character"] = { fg = "#98971a" },

			["@function"] = { fg = "#689d6a" },
			["@function.call"] = { fg = "#689d6a" },
			["@function.builtin"] = { fg = "#d65d0e" },
			["@method"] = { fg = "#689d6a" },
			["@method.call"] = { fg = "#689d6a" },
			["@constructor"] = { fg = "#d79921" },

			["@type"] = { fg = "#d79921", italic = false },
			["@type.builtin"] = { fg = "#d79921", italic = false },
			["@type.definition"] = { fg = "#d79921", italic = false },

			["@property"] = { fg = "#458588" },
			["@field"] = { fg = "#458588" },
			["@namespace"] = { fg = "#458588" },
			["@module"] = { fg = "#458588" },

			["@operator"] = { fg = "#d65d0e" },
			["@punctuation"] = { fg = "#a89984" },
			["@punctuation.bracket"] = { fg = "#a89984" },
			["@punctuation.delimiter"] = { fg = "#a89984" },

			["@tag"] = { fg = "#cc241d" },
			["@tag.attribute"] = { fg = "#d79921" },
			["@tag.delimiter"] = { fg = "#a89984" },

			-- lsp semantic tokens
			["@lsp.type.variable"] = { fg = "#ebdbb2" },
			["@lsp.type.parameter"] = { fg = "#b16286" },
			["@lsp.type.property"] = { fg = "#458588" },
			["@lsp.type.method"] = { fg = "#689d6a" },
			["@lsp.type.function"] = { fg = "#689d6a" },
			["@lsp.type.type"] = { fg = "#d79921" },
			["@lsp.type.struct"] = { fg = "#d79921" },
			["@lsp.type.interface"] = { fg = "#d79921" },
			["@lsp.type.enum"] = { fg = "#d79921" },
			["@lsp.type.keyword"] = { fg = "#cc241d" },

			SignColumn = { bg = "NONE" },
			TabLineFill = { bg = "#282828" },
			TabLineSel = { bg = "#282828" },
			CursorLine = { bg = "#282828" },
			Visual = { bg = "#3c3836" },

			NeoTreeDirectoryName = { fg = "#a89984" },
			NeoTreeRootName = { fg = "#d65d0e" },
			NeoTreeFileName = { fg = "#ebdbb2" },

			NeoTreeGitAdded = { fg = "#98971a" },
			NeoTreeGitConflict = { fg = "#b16286" },
			NeoTreeGitDeleted = { fg = "#cc241d" },
			NeoTreeGitIgnored = { fg = "#393939" },
			NeoTreeGitModified = { fg = "#d65d0e" },
			NeoTreeGitUntracked = { fg = "#d79921" },

			GitSignsAdd = { fg = "#6c7a2a", bg = "NONE" },
			GitSignsChange = { fg = "#8a5a2a", bg = "NONE" },
			GitSignsDelete = { fg = "#7a3a38", bg = "NONE" },
			GitSignsTopdelete = { fg = "#7a3a38", bg = "NONE" },
			GitSignsChangedelete = { fg = "#8a5a2a", bg = "NONE" },
			GitSignsUntracked = { fg = "#8a7a2a", bg = "NONE" },

			-- colorscheme
			-- "#fbf1c7", "#ebdbb2", "#d5c4a1", "#bdae93", "#a89984", "#928374", "#d65d0e", "#cc241d", "#98971a", "#458588", "#b16286", "#689d6a", "#d79921", "#fbf1c7"
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
