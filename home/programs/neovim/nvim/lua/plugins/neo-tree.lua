return {
  "nvim-neo-tree/neo-tree.nvim",
  branch = "v3.x",
  lazy = false,
  dependencies = {
    "nvim-lua/plenary.nvim",
    "MunifTanjim/nui.nvim",
    "nvim-tree/nvim-web-devicons",
  },
  keys = {
    { '<C-n>', ':Neotree toggle left<CR>' },
  },
  opts = {
    window = {
      position = "left",
      width = 40,
    },
    close_if_last_window = true,
    popup_border_style = "rounded",
    filesystem = {
      filtered_items = {
        visible = true,
        never_show = { ".git" },
      },
      window = {
        mappings = {
            ["u"] = "navigate_up",
            ["."] = "set_root",
        },
      },
      follow_current_file = { enabled = true },
    },
    default_component_configs = {
      diagnostics = {
        symbols = {
          hint  = "",
          info  = "",
          warn  = "",
          error = "",
        },
      },
      git_status = {
        symbols = {
          added = "󰬈",
          modified = "󰬔",
          deleted = "󰬋",
          renamed = "󰬙",
          untracked = "󰬛",
          ignored = "󰬐",
          unstaged = "󰬜",
          staged = "󰬚",
          conflict = "󰬊",
        },
      },
    },
  },
}
