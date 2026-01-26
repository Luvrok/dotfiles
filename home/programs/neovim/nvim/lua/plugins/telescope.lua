return {
  "nvim-telescope/telescope.nvim",
  tag = "0.1.8",
  dependencies = {
    "nvim-lua/plenary.nvim",
    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
    { "nvim-telescope/telescope-frecency.nvim" },
    { "ahmedkhalf/project.nvim" },
    { "kkharji/sqlite.lua" },
  },
  keys = {
    { "<leader>p", function() require("telescope.builtin").live_grep() end, desc = "Live grep" },
    { "<C-f>",
      function()
         require("telescope.builtin").current_buffer_fuzzy_find(require("telescope.themes").get_ivy({
          previewer = false,
          prompt_title = "Current Buffer Search",
        }))
      end,
      desc = "Exact substring in current buffer",
    },
    {
      "<C-p>",
      function()
        require("telescope.builtin").find_files({ })
      end,
      desc = "Find files (exact match)",
    },
    { "<leader>o", "<cmd>Telescope projects<cr>", desc = "Projects" },
  },
  config = function()
    local actions = require("telescope.actions")

    require("telescope").setup({
      defaults = {
        mappings = {
          i = {
            ["<C-q>"] = actions.close,
          },
          n = {
            ["<C-q>"] = actions.close,
          },
        },
        vimgrep_arguments = {
          "rg",
          "--color=never",
          "--no-heading",
          "--with-filename",
          "--line-number",
          "--column",
          "--smart-case",
        },

        initial_mode = "insert",
        selection_caret = "",
        entry_prefix = " ",
        scroll_strategy = "limit",
        results_title = false,
        path_display = { "absolute" },
        file_ignore_patterns = { ".git/", ".cache", "%.class", "%.pdf", "%.mkv", "%.mp4", "%.zip" },
        file_previewer = require("telescope.previewers").vim_buffer_cat.new,
        grep_previewer = require("telescope.previewers").vim_buffer_vimgrep.new,
        qflist_previewer = require("telescope.previewers").vim_buffer_qflist.new,
        file_sorter = require("telescope.sorters").get_fuzzy_file,
        generic_sorter = require("telescope.sorters").get_generic_fuzzy_sorter,
      },
      extensions = {
        fzf = {
          fuzzy = false,
          override_generic_sorter = true,
          override_file_sorter = true,
          case_mode = "smart_case",
        },
        frecency = {
          show_scores = true,
          show_unindexed = true,
          ignore_patterns = { "*.git/*", "*/tmp/*" },
        },
      },
    })

    require("telescope").load_extension("fzf")
    require("telescope").load_extension("frecency")
    require("telescope").load_extension("projects")
  end,
}
