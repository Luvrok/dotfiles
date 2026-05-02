return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	lazy = false,
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
	},
	keys = {
		{ "<C-n>", ":Neotree toggle left<CR>" },
	},
	opts = {
		window = {
			position = "left",
			width = 40,
		},
		close_if_last_window = true,
		filesystem = {
			filtered_items = {
				visible = true,
				never_show = { ".git" },
			},
			window = {
				mappings = {
					["u"] = "navigate_up",
					["."] = "set_root",
				},
			},
			follow_current_file = { enabled = true },
		},
		default_component_configs = {
			diagnostics = {
				signs = false,
				symbols = {
					hint = "",
					info = "",
					warn = "",
					error = "E",
				},
			},
			icon = {
				enabled = false,
			},
			indent = {
				with_markers = false,
				indent_marker = " ",
				last_indent_marker = " ",
				indent_size = 1,
			},
			git_status = {
				symbols = {
					added = "A",
					modified = "M",
					deleted = "D",
					renamed = "R",
					untracked = "U",
					ignored = "I",
					unstaged = "U",
					staged = "S",
					conflict = "C",
				},
				align = "right",
			},
		},
	},
}
