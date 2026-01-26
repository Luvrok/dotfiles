return {
  "rebelot/kanagawa.nvim",
  config = function()
    local kanagawa = require("kanagawa")
    kanagawa.setup({
      transparent = false,
      commentStyle = { italic = false },
      theme = "dargon",
      background = {
        dark = "dragon",
        light = "lotus",
      },
    })
    vim.cmd("colorscheme kanagawa")
  end,
}
