return {
	"karb94/neoscroll.nvim",
	config = function()
		require("neoscroll").setup({
			mappings = {
				"<C-u>",
				"<C-d>",
			},
		})

		local keymap = {
			["<PageUp>"] = function()
				require("neoscroll").ctrl_u({ duration = 100 })
			end,
			["<PageDown>"] = function()
				require("neoscroll").ctrl_d({ duration = 100 })
			end,
		}

		for key, func in pairs(keymap) do
			vim.keymap.set({ "n", "x" }, key, func)
		end
	end,
}
