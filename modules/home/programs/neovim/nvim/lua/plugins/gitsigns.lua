local signs = {
	add = { text = "┃" },
	change = { text = "┃" },
	delete = { text = "_" },
	topdelete = { text = "‾" },
	changedelete = { text = "~" },
	untracked = { text = "┆" },
}

return {
	"lewis6991/gitsigns.nvim",
	event = "BufReadPre",
	opts = {
		signs = signs,
		signs_staged = signs,
		signs_staged_enable = true,
		max_file_length = 40000,
		on_attach = function(buf)
			local gs = require("gitsigns")
			local map = function(mode, lhs, rhs, desc)
				vim.keymap.set(mode, lhs, rhs, { buffer = buf, silent = true, desc = desc })
			end
			map("n", "]h", function()
				gs.nav_hunk("next")
			end, "Next hunk")
			map("n", "[h", function()
				gs.nav_hunk("prev")
			end, "Previous hunk")
			map("n", "<leader>hs", gs.stage_hunk, "Stage hunk")
			map("n", "<leader>hr", gs.reset_hunk, "Reset hunk")
			map("x", "<leader>hs", function()
				gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end, "Stage lines")
			map("x", "<leader>hr", function()
				gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
			end, "Reset lines")
			map("n", "<leader>hp", gs.preview_hunk_inline, "Preview hunk")
			map("n", "<leader>hb", function()
				gs.blame_line({ full = true })
			end, "Blame line")
			map({ "o", "x" }, "ih", gs.select_hunk, "Hunk")
		end,
	},
}
