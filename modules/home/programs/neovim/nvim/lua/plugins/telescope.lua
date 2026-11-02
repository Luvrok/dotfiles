local pick = function(name)
	return function()
		require("util.pick")[name]()
	end
end

return {
	"nvim-telescope/telescope.nvim",
	cmd = { "Telescope" },
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
		{ "nvim-telescope/telescope-ui-select.nvim" },
		{ "DrKJeff16/project.nvim" },
	},
	keys = {
		{ "<C-p>", pick("files"), mode = { "n", "x" }, desc = "Find file" },
		{ "<leader>p", pick("grep"), mode = { "n", "x" }, desc = "Find text" },
		{ "<leader>o", pick("projects"), mode = { "n", "x" }, desc = "Projects" },
		{
			"<leader>b",
			function()
				local make_entry = require("telescope.make_entry")
				local actions = require("telescope.actions")
				require("telescope.builtin").buffers({
					initial_mode = "normal",
					sort_lastused = true,
					ignore_current_buffer = true,
					show_all_buffers = true,
					-- the path from the cwd, no buffer numbers and flags
					entry_maker = function(entry)
						local e = make_entry.gen_from_buffer({})(entry)
						e.display = function()
							return vim.fn.fnamemodify(entry.info.name, ":~:.")
						end
						return e
					end,
					attach_mappings = function(_, map)
						map("n", "d", actions.delete_buffer)
						return true
					end,
				})
			end,
			desc = "Buffers",
		},
		{
			"<C-f>",
			function()
				local p = require("util.pick")
				require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
					previewer = true,
					prompt_title = "search",
					layout_config = { width = p.width, height = p.height },
					borderchars = {
						prompt = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
						results = { "─", "│", "─", "│", "├", "┤", "┘", "└" },
						preview = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
					},
				}))
			end,
			mode = { "n", "x" },
			desc = "Find in buffer",
		},
	},
	config = function()
		local telescope = require("telescope")
		local actions = require("telescope.actions")
		local previewers = require("telescope.previewers")
		local p = require("util.pick")

		telescope.setup({
			defaults = vim.tbl_extend("force", p.titles, {
				layout_strategy = "horizontal",
				dynamic_preview_title = false,
				layout_config = {
					horizontal = {
						prompt_position = "bottom",
						width = p.width,
						height = p.height,
						preview_cutoff = 100,
						preview_width = function(_, total_columns)
							if total_columns < 110 then
								return math.floor(total_columns * 0.45)
							elseif total_columns < 160 then
								return math.floor(total_columns * 0.55)
							end
							return math.floor(total_columns * 0.60)
						end,
					},
				},
				borderchars = { "─", "│", "─", "│", "┌", "┐", "┘", "└" },
				get_status_text = function()
					return ""
				end,
				path_display = { "filename_first" },
				mappings = {
					i = { ["<C-q>"] = actions.close },
					n = { ["<C-q>"] = actions.close },
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
				file_previewer = previewers.vim_buffer_cat.new,
				grep_previewer = previewers.vim_buffer_vimgrep.new,
				qflist_previewer = previewers.vim_buffer_qflist.new,
			}),
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
			},
		})

		telescope.load_extension("fzf")
		telescope.load_extension("projects")
		telescope.load_extension("ui-select")

		for _, part in ipairs({ "Prompt", "Results", "Preview" }) do
			vim.api.nvim_set_hl(0, "Telescope" .. part .. "Border", { fg = "#d65d0e" })
			vim.api.nvim_set_hl(0, "Telescope" .. part .. "Title", { fg = "#d65d0e" })
		end
	end,
}
