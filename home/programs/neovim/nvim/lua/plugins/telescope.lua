return {
	"nvim-telescope/telescope.nvim",
	tag = "0.1.8",
	cmd = { "Telescope" },
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		{ "nvim-telescope/telescope-ui-select.nvim" },
		{ "nvim-telescope/telescope-frecency.nvim" },
		{ "ahmedkhalf/project.nvim" },
		{ "kkharji/sqlite.lua" },
	},
	keys = {
		{
			"<leader>p",
			function()
				require("telescope.builtin").live_grep({
					prompt_title = "search",
					results_title = "files",
					preview_title = "preview",
				})
			end,
			mode = { "n", "x" },
		},
		{
			"<C-f>",
			function()
				require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
					previewer = false,
					layout_config = {
						width = function(_, max_columns)
							if max_columns < 100 then
								return math.floor(max_columns * 0.95)
							elseif max_columns < 140 then
								return math.floor(max_columns * 0.85)
							else
								return math.min(math.floor(max_columns * 0.78), 160)
							end
						end,

						height = function(_, _, max_lines)
							if max_lines < 30 then
								return math.floor(max_lines * 0.9)
							else
								return math.min(math.floor(max_lines * 0.85), 42)
							end
						end,
					},
					borderchars = {
						prompt = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
						results = { "─", "│", "─", "│", "├", "┤", "┘", "└" },
						preview = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
					},
					prompt_title = "search",
				}))
			end,
			mode = { "n", "x" },
		},
		{
			"<C-p>",
			function()
				require("telescope.builtin").find_files({
					prompt_title = "search",
					results_title = "files",
					preview_title = "preview",
				})
			end,
			mode = { "n", "x" },
		},
		{
			"<leader>o",
			function()
				require("telescope").extensions.projects.projects({
					prompt_title = "search",
					results_title = "projects",
					preview_title = "preview",
				})
			end,
			mode = { "n", "x" },
		},
	},
	config = function()
		local actions = require("telescope.actions")
		local telescope = require("telescope")

		telescope.setup({
			defaults = {
				layout_strategy = "horizontal",
				dynamic_preview_title = false,
				prompt_title = "search",
				results_title = "files",
				preview_title = "preview",

				layout_config = {
					horizontal = {
						prompt_position = "bottom",

						width = function(_, max_columns)
							if max_columns < 100 then
								return math.floor(max_columns * 0.95)
							elseif max_columns < 140 then
								return math.floor(max_columns * 0.85)
							else
								return math.min(math.floor(max_columns * 0.78), 160)
							end
						end,

						height = function(_, _, max_lines)
							if max_lines < 30 then
								return math.floor(max_lines * 0.9)
							else
								return math.min(math.floor(max_lines * 0.85), 42)
							end
						end,

						preview_cutoff = 100,

						preview_width = function(_, total_columns)
							if total_columns < 110 then
								return math.floor(total_columns * 0.45)
							elseif total_columns < 160 then
								return math.floor(total_columns * 0.55)
							else
								return math.floor(total_columns * 0.60)
							end
						end,
					},
				},

				borderchars = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },

				get_status_text = function()
					return ""
				end,

				path_display = { "filename_first" },

				mappings = {
					i = {
						["<C-q>"] = actions.close,
					},
					n = {
						["<C-q>"] = actions.close,
					},
				},

				prompt_prefix = " ",
				selection_caret = " ",
				entry_prefix = " ",

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
				["ui-select"] = {
					require("telescope.themes").get_dropdown({
						layout_config = {
							height = function(_, _, max_lines)
								return math.min(max_lines, 12)
							end,
						},
					}),
				},
				fzf = {
					fuzzy = false,
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
		telescope.load_extension("ui-select")

		vim.api.nvim_set_hl(0, "TelescopePromptBorder", { fg = "#d65d0e" })
		vim.api.nvim_set_hl(0, "TelescopeResultsBorder", { fg = "#d65d0e" })
		vim.api.nvim_set_hl(0, "TelescopePreviewBorder", { fg = "#d65d0e" })

		vim.api.nvim_set_hl(0, "TelescopePromptTitle", { fg = "#d65d0e" })
		vim.api.nvim_set_hl(0, "TelescopeResultsTitle", { fg = "#d65d0e" })
		vim.api.nvim_set_hl(0, "TelescopePreviewTitle", { fg = "#d65d0e" })
	end,
}
