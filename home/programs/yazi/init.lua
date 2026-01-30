local gruvbox_theme = require("yatline-gruvbox"):setup("dark")

require("full-border"):setup {
  type = ui.Border.PLAIN,
}

require("yatline"):setup({
  theme = gruvbox_theme,

  section_separator = { open = "", close = "" },
  part_separator = { open = "", close = "" },
  inverse_separator = { open = "tab", close = "" },

  tab_width = 20,

  show_background = false,

  display_header_line = true,
  display_status_line = true,

  header_line = {
    left = {
      section_a = {
        { type = "string", custom = false, name = "tab_path", params = { trimed = false, max_length=24, trim_length=10 } },
      },
      section_b = {},
      section_c = {},
    },
    right = {
      section_a = {
        { type = "string", custom = false, name = "date", params = {"%A, %d %B %Y"} },
      },
      section_b = {},
      section_c = {},
    },
  },

  status_line = {
    left = {
      section_a = {
        { type = "string", custom = false, name = "tab_mode" },
      },
      section_b = {
        { type = "string", custom = false, name = "hovered_size" },
      },
      section_c = {
        { type = "string", custom = false, name = "hovered_name" },
      },
    },
    right = {
      section_a = {
      },
      section_b = {
        { type = "string", custom = false, name = "cursor_percentage" },
      },
      section_c = {
        { type = "coloreds", custom = false, name = "permissions" },
      },
    },
  },
})

require("githead"):setup({
  branch_prefix = "on",
  branch_symbol = " ",
  branch_borders = "()",
})
