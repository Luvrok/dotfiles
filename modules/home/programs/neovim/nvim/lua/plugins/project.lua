-- maintained fork of ahmedkhalf/project.nvim, same telescope "projects" picker
return {
	"DrKJeff16/project.nvim",
	lazy = false,
	opts = {
		patterns = { ".git", "Makefile", "package.json", "pyproject.toml", "Cargo.toml", "go.mod" },
		show_hidden = true,
		silent_chdir = true,
		telescope = {
			-- the fork puts rename_project here, that would take telescope's next item key
			mappings = { i = { ["<C-n>"] = false } },
		},
	},
}
