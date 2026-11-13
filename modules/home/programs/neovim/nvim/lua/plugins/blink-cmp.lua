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

		-- <CR> is below: it accepts in the open menu only, otherwise a newline
		keymap = {
			preset = "none",
			["<Tab>"] = { "accept", "snippet_forward", "fallback" },
			["<S-Tab>"] = { "snippet_backward", "fallback" },
			-- the ghost text is accepted by enter in the menu, by the right
			-- arrow anywhere, and by tab above
			["<CR>"] = {
				function(cmp)
					if not cmp.is_menu_visible() then return false end
					return cmp.accept()
				end,
				"fallback",
			},
			["<Right>"] = { "accept", "fallback" },
			-- opens the menu, again closes it. docs open by themselves next to it
			["<C-space>"] = { "show", "hide" },
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
				-- preselect is what makes the ghost text acceptable at all:
				-- without a selected item blink has nothing to accept
				selection = { preselect = true, auto_insert = false },
			},
			-- no menu while typing: the first item shows inline and
			-- <C-n>/<C-p> cycle it. <C-space> toggles the menu
			ghost_text = {
				enabled = true,
				show_with_menu = false,
				show_without_menu = true,
				show_with_selection = true,
				show_without_selection = true,
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

		signature = {
			enabled = true,
			trigger = {
				enabled = true,
				show_on_trigger_character = true,
				show_on_insert_on_trigger_character = true,
			},
			window = {
				border = "rounded",
				max_width = 80,
				max_height = 10,
				show_documentation = true,
				treesitter_highlighting = true,
			},
		},

		sources = {
			default = { "lsp", "path", "buffer" },
		},
	},
}
