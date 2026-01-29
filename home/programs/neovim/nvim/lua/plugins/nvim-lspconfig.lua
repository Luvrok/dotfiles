return {
  "neovim/nvim-lspconfig",
  dependencies = {
    "mason-org/mason.nvim",
    "mason-org/mason-lspconfig.nvim",
    "hrsh7th/cmp-nvim-lsp",
    "hrsh7th/cmp-buffer",
    "hrsh7th/cmp-path",
    "hrsh7th/cmp-cmdline",
    "hrsh7th/nvim-cmp",
    "L3MON4D3/LuaSnip",
    { "j-hui/fidget.nvim", opts = {} },
  },

  config = function()
    local cmp = require("cmp")
    local cmp_lsp = require("cmp_nvim_lsp")
    local capabilities = vim.tbl_deep_extend(
      "force",
      {},
      vim.lsp.protocol.make_client_capabilities(),
      cmp_lsp.default_capabilities()
    )
    require("mason").setup()

    require("mason-lspconfig").setup({
      ensure_installed = {
        "bashls",
        "clangd",
        "cmake",
        "cssls",
        "gopls",
        "html",
        "jsonls",
        "lua_ls",
        "vimls",
      },
      handlers = {
        -- Default handler for LSP servers
        function(server_name)
          require("lspconfig")[server_name].setup({
            capabilities = capabilities,
          })
        end,
      },
    })

    -- nil (nix lsp)
    local lsp_path = vim.env.NIL_PATH or "nil"

    vim.lsp.config("nil_ls", {
      autostart = true,
      capabilities = caps,
      cmd = { lsp_path },
      settings = {
        ["nil"] = {
          testSetting = 42,
          nix = { flake = { autoArchive = true } },
        },
      },
    })

    vim.lsp.enable("nil_ls")

    -- cmp setup
    cmp.setup({
      snippet = {
        expand = function(args)
          require('luasnip').lsp_expand(args.body)
        end,
      },
      mapping = {
        -- confirm with enter if something is selected, if not, insert enter as normal
        ["<CR>"] = cmp.mapping({
          i = function(fallback)
            if cmp.visible() and cmp.get_active_entry() then
              cmp.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = false })
            else
              fallback()
            end
          end,
          s = cmp.mapping.confirm({ select = true }),
          c = cmp.mapping.confirm({ behavior = cmp.ConfirmBehavior.Replace, select = true }),
        }),
        -- Select next with down and previous with up, or fallback if cmp is not visible
        ["<Down>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          else
            fallback()
          end
        end, { "i", "s" }),
        ["<Up>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          else
            fallback()
          end
        end, { "i", "s" }),
        ["<Esc>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.abort()
          else
            fallback()
          end
        end, { "i", "s" }),
      },
      sources = cmp.config.sources({
        -- { name = "copilot" },
        { name = "nvim_lsp" },
        { name = "path" },
        { name = "luasnip" },
      }, {
        { name = "buffer" },
      }),
      preselect = cmp.PreselectMode.None,
      formatting = {
        format = function(_, item)
          item.menu = ""
          return item
        end,
      },
      window = {
        documentation = cmp.config.window.bordered(),
        completion = cmp.config.window.bordered({
          winhighlight = "Normal:CmpPmenu,CursorLine:PmenuSel,Search:None",
        }),
      },
    })

    cmp.setup.cmdline(":", {
      mapping = cmp.mapping.preset.cmdline({
        ["<CR>"] = cmp.mapping(function(fallback)
          if cmp.visible() and cmp.get_active_entry() then
            cmp.confirm({ select = false })
          else
            fallback()
          end
        end, { "c" }),

        ["<Esc>"] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.abort()
          else
            fallback()
          end
        end, { "c" }),
      }),

      sources = cmp.config.sources({ { name = "path" } }, { { name = "cmdline" } }),
    })

    vim.diagnostic.config({
      virtual_text = false,
      underline = true,
      update_in_insert = false,
      severity_sort = true,

      signs = {
        text = {
          [vim.diagnostic.severity.ERROR] = "e",
          [vim.diagnostic.severity.WARN] = "",
          [vim.diagnostic.severity.HINT] = "h",
          [vim.diagnostic.severity.INFO] = "i",
        }
      },

      float = {
        focusable = true,
        style = "minimal",
        border = "rounded",
        source = "always",
        header = "",
        prefix = "",
      },
    })
  end,
}
