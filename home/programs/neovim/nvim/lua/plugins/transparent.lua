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
  end,
}
