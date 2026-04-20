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
		hide_cursor = false, -- Hide cursor while scrolling
		stop_eof = false, -- Stop at <EOF> when scrolling downwards
		respect_scrolloff = true, -- Stop scrolling when the cursor reaches the scrolloff margin of the file
		cursor_scrolls_alone = true, -- The cursor will keep on scrolling even if the window cannot scroll further
		duration_multiplier = 1.0, -- Global duration multiplier
		easing = "quadratic", -- Default easing function
		pre_hook = nil, -- Function to run before the scrolling animation starts
		post_hook = nil, -- Function to run after the scrolling animation ends
		performance_mode = false, -- Disable "Performance Mode" on all buffers.
	},
	config = function()
		local neoscroll = require("neoscroll")
		local modes = { "n", "v", "x" }

		vim.keymap.set(modes, "<Up>", function()
			neoscroll.scroll(-5, { move_cursor = true, duration = 50 })
		end, { desc = "scroll DOWN" })
		vim.keymap.set(modes, "<Down>", function()
			neoscroll.scroll(5, { move_cursor = true, duration = 50 })
		end, { desc = "scroll UP" })
		vim.keymap.set(modes, "<PageUp>", function()
			neoscroll.ctrl_u({ duration = 250 })
		end, { desc = "scroll DOWN" })
		vim.keymap.set(modes, "<PageDown>", function()
			neoscroll.ctrl_d({ duration = 250 })
		end, { desc = "scroll UP" })
		vim.keymap.set("i", "<C-Up>", function()
			neoscroll.scroll(-5, { move_cursor = true, duration = 50 })
		end, { desc = "scroll DOWN" })
		vim.keymap.set("i", "<C-Down>", function()
			neoscroll.scroll(5, { move_cursor = true, duration = 50 })
		end, { desc = "scroll UP" })
	end,
}
