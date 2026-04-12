return {
	"karb94/neoscroll.nvim",
	keys = {
		"<C-u>",
		"<C-d>",
		"<PageUp>",
		"<PageDown>",
	},
	opts = {
		mappings = { "<C-u>", "<C-d>" },
	},
	config = function()
		local neoscroll = require("neoscroll")
		neoscroll.setup(opts)

		vim.keymap.set({ "n", "x" }, "<PageUp>", function()
			neoscroll.ctrl_u({ duration = 100 })
		end)

		vim.keymap.set({ "n", "x" }, "<PageDown>", function()
			neoscroll.ctrl_d({ duration = 100 })
		end)
	end,
}
