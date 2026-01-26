return {
  'numToStr/Comment.nvim',
  keys = {
    { '<C-/>', '<Plug>(comment_toggle_linewise_visual)gv',  mode = 'v', desc = 'Toggle comment (visual)',  silent = true },
    { '<C-/>', '<Plug>(comment_toggle_linewise_current)',  mode = 'n', desc = 'Toggle comment (normal)',  silent = true },
    { '<C-/>', '<esc><Plug>(comment_toggle_linewise_current)gi', mode = 'i', desc = 'Toggle comment(insert)', silent = true },
  },
  config = function()
    require('Comment').setup({})
  end,
}
