return {
	"kevinhwang91/nvim-ufo",
	dependencies = "kevinhwang91/promise-async",
	event = "BufReadPost",
	config = function()
		local ufo = require("ufo")

		vim.o.foldcolumn = "0"
		vim.o.foldtext = " "
		vim.o.foldlevel = 99
		vim.o.foldlevelstart = 99
		vim.o.foldenable = true

		vim.opt.fillchars = {
			eob = " ",
			fold = " ",
			foldopen = " ",
			foldsep = " ",
			foldinner = " ",
			foldclose = " ",
			vert = " ",
		}

		ufo.setup({
			provider_selector = function(_, filetype, buftype)
				-- Disable UFO completely for Neo-tree or any non-file buffer
				if filetype == "neo-tree" or buftype ~= "" then
					return "" -- no providers
				end

				return { "treesitter", "indent" }
			end,
		})

		vim.keymap.set("n", "zR", ufo.openAllFolds)
		vim.keymap.set("n", "zM", ufo.closeAllFolds)
		vim.keymap.set("n", "zr", ufo.openFoldsExceptKinds)
		vim.keymap.set("n", "zm", ufo.closeFoldsWith)
		vim.keymap.set("n", "zk", ufo.peekFoldedLinesUnderCursor)

		vim.keymap.set("n", "za", "za", { desc = "Toggle fold under cursor" })
		vim.keymap.set("n", "zo", "zo", { desc = "Open fold under cursor" })
		vim.keymap.set("n", "zc", "zc", { desc = "Close fold under cursor" })
	end,
}
