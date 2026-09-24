return {
	"saghen/blink.cmp",
	event = "VeryLazy",
	version = "1.*",
	opts = {
		fuzzy = {
			implementation = "lua",
		},

		keymap = {
			preset = "enter",
			["<Tab>"] = { "accept", "fallback" },
			["<CR>"] = { "fallback" }, -- Enter = newline, never accepts
			["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
			["<C-e>"] = { "hide", "fallback" },
			["<C-n>"] = { "select_next", "fallback" },
			["<C-p>"] = { "select_prev", "fallback" },
			["<Up>"] = { "select_prev", "fallback" },
			["<Down>"] = { "select_next", "fallback" },
		},

		appearance = {
			nerd_font_variant = "mono",
		},

		completion = {
			list = {
				selection = { preselect = true, auto_insert = false },
			},
			ghost_text = {
				enabled = true,
				show_with_menu = true,
				show_without_menu = true,    -- inline preview while typing
				show_with_selection = true,
				show_without_selection = false,
			},
			documentation = {
				auto_show = true,
				auto_show_delay_ms = 250,
				treesitter_highlighting = true,
			},
			menu = {
				auto_show = false,
				draw = {
					treesitter = { "lsp" },
					columns = {
						{ "label", "label_description", gap = 1 },
						{ "kind" },
					},
					components = {
						kind_icon = {
							text = function()
								return ""
							end,
						},
					},
				},
			},
		},

		signature = { enabled = true },

		sources = {
			default = { "lsp", "path", "buffer" },
		},
	},
}
