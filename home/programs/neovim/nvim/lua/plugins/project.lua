return {
  "ahmedkhalf/project.nvim",
  config = function()
    require("project_nvim").setup({
      manual_mode = false,
      detection_methods = {"pattern", "lsp"},
      patterns = {".git", "Makefile", "package.json", "pyproject.toml", "Cargo.toml", "go.mod"},
      show_hidden = true,
      silent_chdir = true,
      on_config_done = nil,
    })
  end,
}
