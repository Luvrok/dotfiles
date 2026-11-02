-- cmd, filetypes and root markers come from nvim-lspconfig (lsp/<name>.lua),
-- here only what differs. capabilities come from blink, its plugin file
-- sets them on vim.lsp.config("*"). binaries come from nix, no mason

local flake = vim.env.HOME .. "/HOME/infra/dotfiles"
-- hostName = username, which is also the nixosConfigurations name
local host = vim.uv.os_gethostname()

vim.lsp.config("nixd", {
	-- nixd logs every request to stderr and nvim writes all of it to lsp.log as errors
	cmd = { "nixd", "--log=error" },
	settings = {
		nixd = {
			nixpkgs = {
				expr = ('import (builtins.getFlake "%s").inputs.nixpkgs { }'):format(flake),
			},
			formatting = {
				command = { "nixfmt" },
			},
			options = {
				nixos = {
					expr = ('(builtins.getFlake "%s").nixosConfigurations."%s".options'):format(flake, host),
				},
				home_manager = {
					expr = ('(builtins.getFlake "%s").nixosConfigurations."%s".options.home-manager.users.type.getSubOptions []'):format(
						flake,
						host
					),
				},
			},
		},
	},
})

vim.lsp.config("lua_ls", {
	settings = {
		Lua = {
			runtime = { version = "LuaJIT" },
			diagnostics = { globals = { "vim" } },
			workspace = {
				checkThirdParty = false,
				library = { vim.env.VIMRUNTIME },
			},
			telemetry = { enable = false },
			completion = { callSnippet = "Replace" },
		},
	},
})

vim.lsp.config("gopls", {
	settings = {
		gopls = {
			gofumpt = true,
			staticcheck = true,
			analyses = {
				unusedparams = true,
				shadow = true,
			},
			-- inlay hints, gopls has them all off by default
			hints = {
				assignVariableTypes = true,
				compositeLiteralFields = true,
				constantValues = true,
				functionTypeParameters = true,
				parameterNames = true,
				rangeVariableTypes = true,
			},
		},
	},
})

vim.lsp.config("bashls", {
	settings = {
		bashIde = {
			-- same exclude as writeShellApplication in home/packages.nix
			shellcheckArguments = "--exclude=SC2016",
		},
	},
})

vim.lsp.config("tinymist", {
	settings = {
		formatterMode = "typstyle",
		exportPdf = "onSave",
		semanticTokens = "enable",
	},
})

-- prettierd formats these, keep the servers out of it
for _, name in ipairs({ "html", "cssls", "jsonls" }) do
	vim.lsp.config(name, { init_options = { provideFormatter = false } })
end

vim.lsp.enable({
	"nixd",
	"lua_ls",
	"gopls",
	"bashls",
	"marksman",
	"taplo",
	"clangd",
	"sqls",
	"tinymist",
	"ts_ls",
	"html",
	"cssls",
	"jsonls",
	"yamlls",
})

-- inlay hints in every buffer whose server has them (gopls, lua_ls, clangd, ...)
vim.lsp.inlay_hint.enable()

vim.diagnostic.config({
	severity_sort = true,
	float = {
		border = "rounded",
		source = "if_many",
	},
})

vim.api.nvim_create_autocmd("CursorHold", {
	callback = function()
		vim.diagnostic.open_float({
			focus = false,
			scope = "cursor",
			close_events = {
				"BufLeave",
				"CursorMoved",
				"InsertEnter",
				"FocusLost",
			},
		})
	end,
})
