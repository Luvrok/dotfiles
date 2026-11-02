return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false, -- main не поддерживает lazy-loading
		build = ":TSUpdate",
		config = function()
			-- no-op for the ones already installed
			require("nvim-treesitter").install({
				-- languages
				"bash", "c", "cpp", "css", "dockerfile", "go", "gomod", "gosum", "gowork",
				"html", "javascript", "json", "lua", "make", "markdown", "nix", "python",
				"rasi", "rust", "scss", "sql", "toml", "tsx", "typescript", "typst", "xml",
				"yaml", "yuck", "zsh",
				-- git
				"diff", "git_config", "git_rebase", "gitattributes", "gitcommit", "gitignore",
				-- injected into other languages
				"comment", "jsdoc", "luadoc", "luap", "markdown_inline", "printf", "query",
				"regex", "vim", "vimdoc",
			})

			-- big files get filetype "bigfile" from snacks, so they're skipped here too
			vim.api.nvim_create_autocmd("FileType", {
				callback = function(args)
					local lang = vim.treesitter.language.get_lang(args.match)
					-- add() returns nil when there's no parser for it
					if lang and vim.treesitter.language.add(lang) then
						vim.treesitter.start(args.buf, lang)
					end
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
