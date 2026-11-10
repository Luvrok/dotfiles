-- cmd, filetypes and root markers come from nvim-lspconfig (lsp/<name>.lua),
-- here only what differs. capabilities come from blink, its plugin file
-- sets them on vim.lsp.config("*"). binaries come from nix, no mason

local flake = vim.env.HOME .. "/HOME/infra/dotfiles"
-- hostName = username, which is also the nixosConfigurations name
local host = vim.uv.os_gethostname()
local flakeExpr = ('(builtins.getFlake "%s")'):format(flake)

vim.lsp.config("nixd", {
	-- nixd logs every request to stderr and nvim writes all of it to lsp.log as errors
	cmd = { "nixd", "--log=error" },
	settings = {
		nixd = {
			nixpkgs = { expr = ("import %s.inputs.nixpkgs { }"):format(flakeExpr) },
			formatting = { command = { "nixfmt" } },
			options = {
				nixos = {
					expr = ('%s.nixosConfigurations."%s".options'):format(flakeExpr, host),
				},
				home_manager = {
					expr = ('%s.nixosConfigurations."%s".options.home-manager.users.type.getSubOptions []'):format(
						flakeExpr,
						host
					),
				},
			},
		},
	},
})

-- the install prefix of a binary from PATH, following the symlink nixos puts
-- in /run/current-system/sw/bin. the qml modules and hyprland's lua stubs are
-- found from it, no nix paths in this config: it works wherever the binaries
-- are, and skips what isn't installed
local function prefix(exe)
	local path = vim.fn.exepath(exe)
	if path == "" then
		return nil
	end
	return vim.fs.dirname(vim.fs.dirname(vim.uv.fs_realpath(path) or path))
end

local hyprland = prefix("Hyprland")
local luaLibrary = { vim.env.VIMRUNTIME }
if hyprland then
	local stub = hyprland .. "/share/hypr/stubs/hl.meta.lua"
	if vim.uv.fs_stat(stub) then
		table.insert(luaLibrary, stub)
	end
end

vim.lsp.config("lua_ls", {
	settings = {
		Lua = {
			runtime = { version = "LuaJIT" },
			diagnostics = { globals = { "vim", "hl" } },
			workspace = {
				checkThirdParty = false,
				library = luaLibrary,
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

vim.lsp.config("basedpyright", {
	settings = {
		basedpyright = {
			analysis = {
				typeCheckingMode = "standard",
				autoSearchPaths = true,
				useLibraryCodeForTypes = true,
				diagnosticMode = "openFilesOnly",
				inlayHints = { callArgumentNames = true },
			},
		},
	},
})

vim.lsp.config("ruff", {
	init_options = {
		settings = {
			lineLength = 88,
		},
	},
})

vim.lsp.config("bashls", {
	settings = {
		-- $vars in single quotes are on purpose in the jq and awk scripts
		bashIde = { shellcheckArguments = "--exclude=SC2016" },
	},
})

vim.lsp.config("tinymist", {
	settings = {
		formatterMode = "typstyle",
		exportPdf = "onSave",
		semanticTokens = "enable",
	},
})

-- the qml modules of qt and quickshell (import QtQuick, import Quickshell),
-- from the same install prefixes, nothing comes from nix here
local qmlls = { "qmlls" }
for _, exe in ipairs({ "qmlls", "qs" }) do
	local root = prefix(exe)
	local path = root and root .. "/lib/qt-6/qml"
	if path and vim.uv.fs_stat(path) then
		vim.list_extend(qmlls, { "-I", path })
	end
end
vim.lsp.config("qmlls", { cmd = qmlls })

-- javascript / typescript: ts_ls is the server, eslint lints, prettierd
-- formats (conform). both look for the project's own node_modules first, the
-- nix binaries are the fallback. react/vite: ts_ls reads tsconfig/jsconfig,
-- emmet expands jsx and css abbreviations
local jsInlayHints = {
	parameterNames = { enabled = "literals" },
	parameterTypes = { enabled = true },
	variableTypes = { enabled = true },
	propertyDeclarationTypes = { enabled = true },
	functionLikeReturnTypes = { enabled = true },
	enumMemberValues = { enabled = true },
}

vim.lsp.config("ts_ls", {
	settings = {
		typescript = {
			inlayHints = jsInlayHints,
			preferences = {
				jsxAttributeCompletionStyle = "auto",
				includePackageJsonAutoImports = "auto",
				includeCompletionsForModuleExports = true,
			},
		},
		javascript = {
			inlayHints = jsInlayHints,
			preferences = {
				jsxAttributeCompletionStyle = "auto",
				includePackageJsonAutoImports = "auto",
				includeCompletionsForModuleExports = true,
			},
		},
	},
})

vim.lsp.config("eslint", {
	settings = {
		-- flat config is the default from eslint 9, eslintrc still works
		-- through the project's own config file
		workingDirectory = { mode = "location" },
	},
})

-- prettierd formats these, keep the servers out of it
for _, name in ipairs({ "html", "cssls", "jsonls" }) do
	vim.lsp.config(name, { init_options = { provideFormatter = false } })
end

vim.lsp.enable({
	"nixd",
	"basedpyright",
	"ruff",
	"lua_ls",
	"gopls",
	"bashls",
	"marksman",
	"taplo",
	"clangd",
	"sqls",
	"tinymist",
	"ts_ls",
	"eslint",
	"emmet_language_server",
	"html",
	"cssls",
	"jsonls",
	"yamlls",
	"qmlls",
})

-- inlay hints in every buffer whose server has them (gopls, lua_ls, clangd, ...)
vim.lsp.inlay_hint.enable()

vim.diagnostic.config({
	severity_sort = true,
	virtual_text = { spacing = 2, prefix = "●" },
	underline = true,
	update_in_insert = false,
	float = {
		border = "rounded",
		source = "if_many",
	},
})
