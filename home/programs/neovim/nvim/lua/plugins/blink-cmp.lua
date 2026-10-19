return {
	"saghen/blink.cmp",
	version = "1.*",
	-- not lazy: its plugin file puts the completion capabilities on
	-- vim.lsp.config("*"), that has to happen before the first server starts.
	-- blink loads its own modules lazily anyway
	lazy = false,
	opts = {
		fuzzy = {
			-- rust matcher (typo tolerant, better sorting) from the prebuilt binary,
			-- lua matcher if it can't be downloaded
			implementation = "prefer_rust",
		},

		-- <CR> stays unmapped: enter always makes a newline
		keymap = {
			preset = "none",
			["<Tab>"] = { "accept", "snippet_forward", "fallback" },
			["<S-Tab>"] = { "snippet_backward", "fallback" },
			["<C-space>"] = { "show", "show_documentation", "hide_documentation" },
			["<C-e>"] = { "hide", "fallback" },
			["<C-n>"] = { "select_next", "fallback" },
			["<C-p>"] = { "select_prev", "fallback" },
			["<Up>"] = { "select_prev", "fallback" },
			["<Down>"] = { "select_next", "fallback" },
			["<C-b>"] = { "scroll_documentation_up", "fallback" },
			["<C-f>"] = { "scroll_documentation_down", "fallback" },
			["<C-k>"] = { "show_signature", "hide_signature", "fallback" },
		},

		completion = {
			list = {
				selection = { preselect = true, auto_insert = false },
			},
			-- the menu stays hidden, the first item shows inline and
			-- <C-n>/<C-p> cycle it. <C-space> opens the menu
			ghost_text = {
				enabled = true,
				show_with_menu = true,
				show_without_menu = true,
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
				},
			},
		},

		signature = { enabled = true },

		sources = {
			default = { "lsp", "path", "buffer" },
		},
	},
}
