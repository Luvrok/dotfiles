return {
	"mg979/vim-visual-multi",
	branch = "master",
	keys = {
		{ "<M-d>", desc = "Add multicursor next match" },
		{ "<M-s>", desc = "Skip match" },
		{ "<M-x>", desc = "Remove current cursor" },
		{ "<M-j>", desc = "Add cursor down" },
		{ "<M-k>", desc = "Add cursor up" },
	},
	init = function()
		vim.g.VM_default_mappings = 0
		vim.g.VM_maps = {
			["Find Under"] = "<M-d>",
			["Find Subword Under"] = "<M-d>",
			["Skip Region"] = "<M-s>",
			["Remove Region"] = "<M-x>",
			["Add Cursor Down"] = "<M-j>",
			["Add Cursor Up"] = "<M-k>",
		}
		vim.g.VM_theme = "sand"
	end,
}
