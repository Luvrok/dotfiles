local capabilities = vim.lsp.protocol.make_client_capabilities()
local ok, blink = pcall(require, "blink.cmp")
if ok then
	capabilities = blink.get_lsp_capabilities(capabilities)
end

vim.lsp.config("nixd", {
	cmd = { "nixd" },
	filetypes = { "nix" },
	root_markers = { "flake.nix", "default.nix", "shell.nix", ".git" },
	capabilities = capabilities,
	settings = {
		formatting = {
			command = { "nixfmt" },
		},
		nixd = {
			nixpkgs = {
				expr = 'import (builtins.getFlake "/home/barnard/HOME/infra/dotfiles").inputs.nixpkgs { }',
			},
			formatting = {
				command = { "nixfmt" },
			},
			options = {
				nixos = {
					expr = '(builtins.getFlake "/home/barnard/HOME/infra/dotfiles").nixosConfigurations."barnard".options',
				},
				home_manager = {
					expr = '(builtins.getFlake "/home/barnard/HOME/infra/dotfiles").nixosConfigurations."barnard".options.home-manager.users.type.getSubOptions []',
				},
			},
		},
	},
})

vim.lsp.config("tinymist", {
	cmd = { "tinymist" },
	filetypes = { "typst" },
	root_markers = { "typst.toml", ".git" },
	capabilities = capabilities,
	single_file_support = true,
	settings = {
		formatterMode = "typstyle",
		exportPdf = "onSave",
		semanticTokens = "enable",
	},
})

vim.lsp.config("lua_ls", {
	cmd = { "lua-language-server" },
	filetypes = { "lua" },
	single_file_support = true,
	root_markers = {
		".luarc.json",
		".luarc.jsonc",
		".luacheckrc",
		".stylua.toml",
		"stylua.toml",
		"selene.toml",
		"selene.yml",
		".git",
		"Makefile",
	},
	capabilities = capabilities,

	settings = {
		Lua = {
			diagnostics = {
				enable = true,
				globals = { "vim", "require" },
			},
			workspace = {
				checkThirdParty = false,
				library = vim.api.nvim_get_runtime_file("", true),
			},
			telemetry = { enable = false },
			completion = {
				callSnippet = "Replace",
			},
		},
	},
})

vim.lsp.config("bash-language-server", {
	cmd = { "bash-language-server", "start" },
	filetypes = { "bash", "sh" },
	root_markers = { ".git" },
	capabilities = capabilities,
	settings = {
		bashIde = {
			globPattern = vim.env.GLOB_PATTERN or "*@(.sh|.inc|.bash|.command)",
		},
	},
})

vim.lsp.config("gopls", {
	cmd = { "gopls" },
	filetypes = { "go", "gomod" },
	root_markers = { "go.work", "go.mod", ".git" },
	cmd_env = {
		GOOS = "linux",
	},
	settings = {
		gopls = {
			gofumpt = true,
			staticcheck = true,
			analyses = {
				unusedparams = true,
				shadow = true,
			},
			buildFlags = { "-tags=amd64" },
		},
	},
	capabilities = capabilities,
})

vim.lsp.config("marksman", {
	cmd = { "marksman", "server" },
	filetypes = { "markdown" },
	root_markers = { ".marksman.toml" },
	capabilities = capabilities,
})

vim.lsp.config("taplo", {
	cmd = { "taplo", "lsp", "stdio" },
	filetypes = { "toml" },
	root_markers = { ".git" },
	capabilities = capabilities,
})

vim.lsp.config("clangd", {
	cmd = { "clangd" },
	root_markers = { ".git", "compile_commands.json", "CMakeLists.txt" },
	filetypes = { "c", "cpp", "objc", "objcpp" },
	capabilities = capabilities,
})

vim.lsp.config("sqls", {
	cmd = { "sqls" },
	filetypes = { "sql", "mysql" },
	root_markers = { "config.yml" },
	settings = {},
	capabilities = capabilities,
})

vim.lsp.config("vscode-langservers-extracted", {
	cmd = { "vscode-eslint-language-server", "--stdio" },
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "graphql" },
	root_markers = { ".eslintrc", ".eslintrc.js", ".eslintrc.json", "eslint.config.js", "eslint.config.mjs" },
	capabilities = capabilities,
})

vim.lsp.config("typescript-language-server", {
	cmd = { "typescript-language-server", "--stdio" },
	root_markers = { "project.json", "tsconfig.json", "jsconfig.json", ".git" },
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
	capabilities = capabilities,
})

vim.lsp.config("yaml-language-server", {
	cmd = { "yaml-language-server", "--stdio" },
	filetypes = { "yaml" },
	root_markers = {
		".git",
	},
	single_file_support = true,
	capabilities = capabilities,
})

vim.lsp.config("vscode-html-language-server", {
	cmd = { "vscode-html-language-server", "--stdio" },
	filetypes = { "html" },
	root_markers = { "package.json", ".git" },
	single_file_support = true,
	capabilities = capabilities,
	settings = {},
	init_options = {
		provideFormatter = false, -- you format with prettierd
		embeddedLanguages = { css = true, javascript = true },
		configurationSection = { "html", "css", "javascript" },
	},
})

vim.lsp.config("vscode-css-language-server", {
	cmd = { "vscode-css-language-server", "--stdio" },
	filetypes = { "css", "scss", "less" },
	root_markers = { "package.json", ".git" },
	single_file_support = true,
	capabilities = capabilities,
	settings = {
		css = { validate = true },
		scss = { validate = true },
		less = { validate = true },
	},
	init_options = { provideFormatter = false },
})

vim.lsp.config("vscode-json-language-server", {
	cmd = { "vscode-json-language-server", "--stdio" },
	filetypes = { "json", "jsonc" },
	root_markers = { ".git" },
	single_file_support = true,
	capabilities = capabilities,
	init_options = { provideFormatter = false },
})

vim.lsp.enable({
	"nixd",
	"lua_ls",
	"gopls",
	"marksman",
	"taplo",
	"clangd",
	"sqls",
	"tinymist",
	"vscode-langservers-extracted",
	"vscode-html-language-server",
	"vscode-css-language-server",
	"vscode-json-language-server",
	"typescript-language-server",
	"yaml-language-server",
	"bash-language-server",
})

vim.api.nvim_create_autocmd("CursorHold", {
	callback = function()
		vim.diagnostic.open_float(nil, {
			focus = false,
			close_events = {
				"BufLeave",
				"CursorMoved",
				"InsertEnter",
				"FocusLost",
			},
			border = "rounded",
			source = "if_many",
			scope = "cursor",
		})
	end,
})
