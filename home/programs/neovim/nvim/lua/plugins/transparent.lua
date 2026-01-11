return {
  "xiyaowong/transparent.nvim",
  config = function()
    require("transparent").setup({
      enable = true,
      groups = {
        "Normal",
        "NormalNC",
        "NormalFloat",
      },
       exclude_groups = {
        "CursorLine",
        "CursorLineNr",
        "Visual",
        "VisualNOS",
        "Search",
        "IncSearch",
        "Pmenu",
        "PmenuSel",
        "StatusLine",
        "StatusLineNC",
        "WinSeparator",
        "SignColumn",
        "LineNr",
        "EndOfBuffer",
        "FoldColumn",
      },
    })
    local opts = { noremap = true, silent = true }
    opts.desc = "toggle transparancy"
    vim.keymap.set("n", "<leader>vct", "<cmd>TransparentToggle<CR>", opts)
  end,
}
