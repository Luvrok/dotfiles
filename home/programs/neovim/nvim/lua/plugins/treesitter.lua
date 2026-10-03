return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false, -- main не поддерживает lazy-loading
		build = ":TSUpdate",
		config = function()
			require("nvim-treesitter").install({
				"bash", "c", "diff", "html", "javascript", "jsdoc", "json", "nix",
				"lua", "luadoc", "luap", "markdown", "markdown_inline", "printf",
				"query", "regex", "toml", "tsx", "typescript", "vim", "vimdoc",
				"xml", "yaml", "clojure", "go", "css", "scss", "typst",
			})

			vim.api.nvim_create_autocmd("FileType", {
				callback = function(args)
					local buf = args.buf
					local ok, stats = pcall(vim.uv.fs_stat, vim.api.nvim_buf_get_name(buf))
					if ok and stats and stats.size > 200 * 1024 then
						return
					end
					pcall(vim.treesitter.start, buf)
				end,
			})
		end,
	},
	{
		"nvim-treesitter/nvim-treesitter-textobjects",
		branch = "main",
		lazy = false,
		config = function()
			require("nvim-treesitter-textobjects").setup({
				select = { lookahead = true },
				move = { set_jumps = true },
			})

			local sel = require("nvim-treesitter-textobjects.select")
			for key, q in pairs({
				af = "@function.outer", ["if"] = "@function.inner",
				ac = "@class.outer",    ic = "@class.inner",
				aa = "@parameter.outer", ia = "@parameter.inner",
				ab = "@block.outer",    ib = "@block.inner",
			}) do
				vim.keymap.set({ "x", "o" }, key, function()
					sel.select_textobject(q, "textobjects")
				end)
			end

			local move = require("nvim-treesitter-textobjects.move")
			local modes = { "n", "x", "o" }
			vim.keymap.set(modes, "]f", function() move.goto_next_start("@function.outer", "textobjects") end)
			vim.keymap.set(modes, "]c", function() move.goto_next_start("@class.outer", "textobjects") end)
			vim.keymap.set(modes, "[f", function() move.goto_previous_start("@function.outer", "textobjects") end)
			vim.keymap.set(modes, "[c", function() move.goto_previous_start("@class.outer", "textobjects") end)
		end,
	},
}
