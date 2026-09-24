return {
	"akinsho/toggleterm.nvim",
	keys = {
		{ [[<C-\>]] },
	},
	cmd = { "ToggleTerm", "TermExec" },
	opts = {
		open_mapping = [[<C-\>]],
		shade_terminals = false,
		shading_factor = 0.3,
		start_in_insert = true,
		persist_mode = false,
		persist_size = true,
		direction = "float",

		float_opts = {
			border = "single",
			width = 80,
			height = 20,
			row = function()
				return math.floor((vim.o.lines - 20) / 2)
			end,
			col = function()
				return math.floor((vim.o.columns - 80) / 2)
			end,
		},

		on_open = function(term)
			vim.cmd("startinsert!")

			local opts = { buffer = term.bufnr, silent = true, noremap = true }

			-- Esc сразу закрывает терминал
			vim.keymap.set("t", "<Esc>", "<cmd>close<CR>", opts)

			-- на всякий случай, если случайно попал в normal внутри окна терминала
			vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", opts)
			vim.keymap.set("n", "q", "<cmd>close<CR>", opts)
		end,

		highlights = {
			NormalFloat = {
				guibg = "NONE",
			},
			FloatBorder = {
				guifg = "#d65d0e",
				guibg = "NONE",
			},
		},

		winbar = {
			enabled = false,
			name_formatter = function(term)
				return term.name
			end,
		},
	},
}
