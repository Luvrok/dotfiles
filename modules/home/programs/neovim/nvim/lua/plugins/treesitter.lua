-- stylua: ignore
local parsers = {
	-- languages
	"bash", "c", "cpp", "css", "dockerfile", "go", "gomod", "gosum", "gowork",
	"html", "javascript", "json", "latex", "lua", "make", "markdown", "nix", "python",
	"qmljs", "rust", "scss", "sql", "toml", "tsx", "typescript", "typst", "xml",
	"yaml", "zsh",
	-- git
	"diff", "git_config", "git_rebase", "gitattributes", "gitcommit", "gitignore",
	-- injected into other languages
	"comment", "jsdoc", "luadoc", "luap", "markdown_inline", "printf", "query",
	"regex", "vim", "vimdoc",
}

return {
	{
		"nvim-treesitter/nvim-treesitter",
		branch = "main",
		lazy = false, -- main has no lazy loading
		build = ":TSUpdate",
		config = function()
			-- no-op for the ones already installed
			require("nvim-treesitter").install(parsers)

			-- .qml files are filetype qml, the parser is qmljs
			vim.treesitter.language.register("qmljs", "qml")

			-- big files get filetype "bigfile" from snacks, so they're skipped here too
			vim.api.nvim_create_autocmd("FileType", {
				group = vim.api.nvim_create_augroup("user-treesitter", { clear = true }),
				callback = function(args)
					local lang = vim.treesitter.language.get_lang(args.match)
					-- add() returns nil when there's no parser for it
					if not (lang and vim.treesitter.language.add(lang)) then
						return
					end
					vim.treesitter.start(args.buf, lang)
					-- treesitter indent only where nvim has no indent file for the
					-- filetype (qml, typst...). nix keeps vim-nix's
					if vim.bo[args.buf].indentexpr == "" then
						vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
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

			local select = require("nvim-treesitter-textobjects.select")
			for key, query in pairs({
				af = "@function.outer",
				["if"] = "@function.inner",
				ac = "@class.outer",
				ic = "@class.inner",
				aa = "@parameter.outer",
				ia = "@parameter.inner",
				ab = "@block.outer",
				ib = "@block.inner",
			}) do
				vim.keymap.set({ "x", "o" }, key, function()
					select.select_textobject(query, "textobjects")
				end)
			end

			local move = require("nvim-treesitter-textobjects.move")
			for key, fn in pairs({
				["]f"] = { "goto_next_start", "@function.outer" },
				["[f"] = { "goto_previous_start", "@function.outer" },
				["]c"] = { "goto_next_start", "@class.outer" },
				["[c"] = { "goto_previous_start", "@class.outer" },
			}) do
				vim.keymap.set({ "n", "x", "o" }, key, function()
					move[fn[1]](fn[2], "textobjects")
				end)
			end
		end,
	},
}
