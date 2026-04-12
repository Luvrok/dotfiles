vim.lsp.config("nixd", {
	cmd = { "nixd" },
	filetypes = { "nix" },
	root_markers = { "flake.nix", "default.nix", "shell.nix", ".git" },
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

-- vim.lsp.config("nil_ls", {
-- 	cmd = { "nil" },
-- 	filetypes = { "nix" },
-- 	root_markers = { "flake.nix", "default.nix", "shell.nix", ".git" },
-- 	settings = {
-- 		["nil"] = {
-- 			formatting = {
-- 				command = { "nixfmt" },
-- 			},
-- 		},
-- 	},
-- })

vim.lsp.config("lua_ls", {
	name = "lua_ls",
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
	settings = {
		bashIde = {
			globPattern = vim.env.GLOB_PATTERN or "*@(.sh|.inc|.bash|.command)",
		},
	},
})

vim.lsp.config("gopls", {
	cmd = { "gopls" },
	filetypes = { "go", "gomod" },
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
})

vim.lsp.config("marksman", {
	cmd = { "marksman", "server" },
	filetypes = { "markdown" },
	root_markers = { ".marksman.toml" },
})

vim.lsp.config("taplo", {
	cmd = { "taplo", "lsp", "stdio" },
	filetypes = { "toml" },
	root_markers = { ".git" },
})

vim.lsp.config("clangd", {
	cmd = { "clangd" },
	root_markers = { ".git", "compile_commands.json", "CMakeLists.txt" },
	filetypes = { "c", "cpp", "objc", "objcpp" },
})

vim.lsp.config("sqls", {
	cmd = { "sqls" },
	filetypes = { "sql", "mysql" },
	root_markers = { "config.yml" },
	settings = {},
})

vim.lsp.config("vscode-langservers-extracted", {
	cmd = { "vscode-eslint-language-server", "--stdio" },
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact", "graphql" },
	root_markers = { ".eslintrc", ".eslintrc.js", ".eslintrc.json", "eslint.config.js", "eslint.config.mjs" },
})

vim.lsp.config("typescript-language-server", {
	cmd = { "typescript-language-server", "--stdio" },
	root_markers = { "project.json", "tsconfig.json", "jsconfig.json", ".git" },
	filetypes = { "javascript", "javascriptreact", "typescript", "typescriptreact" },
})

vim.lsp.config("yaml-language-server", {
	cmd = { "yaml-language-server", "--stdio" },
	filetypes = { "yaml" },
	root_markers = {
		".git",
	},
	single_file_support = true,
})

vim.lsp.enable({
	"nixd",
	"lua_ls",
	"gopls",
	"marksman",
	"taplo",
	"clangd",
	"sqls",
	"vscode-langservers-extracted",
	"typescript-language-server",
	"yaml-language-server",
	"bash-language-server",
})
