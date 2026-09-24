return {
	"ahmedkhalf/project.nvim",
	main = "project_nvim",
	lazy = false,
	opts = {
		manual_mode = false,
		detection_methods = { "pattern", "lsp" },
		patterns = { ".git", "Makefile", "package.json", "pyproject.toml", "Cargo.toml", "go.mod" },
		show_hidden = true,
		silent_chdir = true,
	},
}
