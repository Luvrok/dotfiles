return {
	"nvim-telescope/telescope.nvim",
	tag = "0.1.8",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		{ "nvim-telescope/telescope-frecency.nvim" },
		{ "ahmedkhalf/project.nvim" },
		{ "kkharji/sqlite.lua" },
	},
	keys = {
		{
			"<leader>p",
			function()
				require("telescope.builtin").live_grep()
			end,
			desc = "Live grep",
		},
		{
			"<C-f>",
			function()
				require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_ivy({
					previewer = false,
					prompt_title = false,
				}))
			end,
			desc = "Fuzzy find in current buffer",
		},
		{
			"<C-p>",
			function()
				require("telescope.builtin").find_files()
			end,
			desc = "Find files",
		},
		{ "<leader>o", "<cmd>Telescope projects<cr>", desc = "Projects" },
	},
	config = function()
		local actions = require("telescope.actions")
		local telescope = require("telescope")

		telescope.setup({
			defaults = {
				layout_strategy = "horizontal",
				layout_config = {
					width = 0.9,
					height = 0.9,
					preview_cutoff = 1,
					horizontal = {
						preview_width = 0.6,
					},
				},

				prompt_prefix = "",
				selection_caret = "",
				entry_prefix = "",

				get_status_text = function()
					return ""
				end,

				results_title = false,
				path_display = { "filename_first" },

				mappings = {
					i = {
						["<C-q>"] = actions.close,
					},
					n = {
						["<C-q>"] = actions.close,
					},
				},

				borderchars = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
				vimgrep_arguments = {
					"rg",
					"--color=never",
					"--no-heading",
					"--with-filename",
					"--line-number",
					"--column",
					"--smart-case",
				},

				initial_mode = "insert",
				scroll_strategy = "cycle",

				file_ignore_patterns = { ".git/", ".cache", "%.class", "%.pdf", "%.mkv", "%.mp4", "%.zip" },

				file_previewer = require("telescope.previewers").vim_buffer_cat.new,
				grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
				qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
			},

			extensions = {
				fzf = {
					fuzzy = true,
					override_generic_sorter = true,
					override_file_sorter = true,
					case_mode = "smart_case",
				},
				frecency = {
					show_scores = false,
					show_unindexed = true,
					ignore_patterns = { "*.git/*", "*/tmp/*" },
				},
			},
		})

		telescope.load_extension("fzf")
		telescope.load_extension("frecency")
		telescope.load_extension("projects")

		vim.api.nvim_set_hl(0, "TelescopePromptBorder", { fg = "#d65d0e" })
		vim.api.nvim_set_hl(0, "TelescopeResultsBorder", { fg = "#d65d0e" })
		vim.api.nvim_set_hl(0, "TelescopePreviewBorder", { fg = "#d65d0e" })

		vim.api.nvim_set_hl(0, "TelescopePromptTitle", { fg = "#d65d0e" })
		vim.api.nvim_set_hl(0, "TelescopeResultsTitle", { fg = "#d65d0e" })
		vim.api.nvim_set_hl(0, "TelescopePreviewTitle", { fg = "#d65d0e" })
	end,
}
