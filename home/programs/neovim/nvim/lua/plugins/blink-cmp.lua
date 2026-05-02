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
		},

		appearance = {
			nerd_font_variant = "mono",
		},

		completion = {
			ghost_text = {
				enabled = true,
			},
			documentation = {
				auto_show = false,
				auto_show_delay_ms = 200,
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

		sources = {
			default = { "lsp", "path", "buffer" },
		},
	},
}
