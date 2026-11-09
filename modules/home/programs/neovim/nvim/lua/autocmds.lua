local group = vim.api.nvim_create_augroup("user", { clear = true })

-- flash what was yanked
vim.api.nvim_create_autocmd("TextYankPost", {
	group = group,
	callback = function()
		vim.hl.on_yank({ timeout = 150 })
	end,
})

-- reopen a file where it was left
vim.api.nvim_create_autocmd("BufReadPost", {
	group = group,
	callback = function(args)
		local ft = vim.bo[args.buf].filetype
		if ft == "gitcommit" or ft == "gitrebase" then
			return
		end
		local mark = vim.api.nvim_buf_get_mark(args.buf, '"')
		if mark[1] > 0 and mark[1] <= vim.api.nvim_buf_line_count(args.buf) then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

-- python uses four spaces, ruff and basedpyright expect 88 columns
vim.api.nvim_create_autocmd("FileType", {
	group = group,
	pattern = "python",
	callback = function()
		vim.opt_local.shiftwidth = 4
		vim.opt_local.tabstop = 4
		vim.opt_local.softtabstop = 4
		vim.opt_local.expandtab = true
		vim.opt_local.colorcolumn = "88"
	end,
})

-- the diagnostic under the cursor in a float, after updatetime
vim.api.nvim_create_autocmd("CursorHold", {
	group = group,
	callback = function()
		vim.diagnostic.open_float({
			focus = false,
			scope = "cursor",
			close_events = { "BufLeave", "CursorMoved", "InsertEnter", "FocusLost" },
		})
	end,
})
