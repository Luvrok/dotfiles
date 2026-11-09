local map = function(mode, lhs, rhs, opts)
	vim.keymap.set(mode, lhs, rhs, vim.tbl_extend("force", { silent = true }, opts or {}))
end

-- undo and redo on ctrl+z and ctrl+y, u and ctrl+r do nothing
map({ "n", "x" }, "u", "<Nop>")
map({ "n", "x" }, "<C-r>", "<Nop>")
map("n", "<C-z>", "u")
map("n", "<C-y>", "<C-r>")
-- in visual mode u lowercases the selection, so leave it first
map("x", "<C-z>", "<Esc>u")
map("x", "<C-y>", "<Esc><C-r>")
map("i", "<C-z>", "<C-o>u")
map("i", "<C-y>", "<C-o><C-r>")

-- windows
map("n", "<C-h>", "<C-w>h")
map("n", "<C-j>", "<C-w>j")
map("n", "<C-k>", "<C-w>k")
map("n", "<C-l>", "<C-w>l")

-- system clipboard
map("n", "<C-c>", '"+y')
map("n", "<C-x>", '"+d')
map("x", "<C-c>", '"+ygv')
map("x", "<C-x>", '"+dgv')
map({ "n", "x" }, "<C-v>", '"+p')
map("i", "<C-v>", "<C-r>+")
map({ "n", "i", "x" }, "<C-a>", "<Esc>ggVG", { desc = "Select all" })

-- buffers and tabs. ctrl+w closes the buffer, so the <C-w> window
-- commands are gone: splits are :vsp and :sp. Snacks.bufdelete keeps the
-- window, neo-tree doesn't take over the screen. alt+left/right go through
-- the buffers (plugins/bufferline.lua)
map("n", "<C-t>", "<cmd>tabnew<CR>")
map("n", "<C-w>", function()
	Snacks.bufdelete()
end, { desc = "Close buffer" })

-- save, quit
map({ "n", "i", "x" }, "<C-s>", "<cmd>silent w<CR>", { desc = "Save" })
map("n", "q", "<cmd>confirm qall<CR>", { desc = "Quit all" })
map("x", "q", "<Nop>")

-- off: search jumps, visual block
map("n", "n", "<Nop>")
map("n", "N", "<Nop>")
map({ "n", "i", "x" }, "<C-q>", "<Nop>")

-- delete a word back in insert mode
map("i", "<C-BS>", "<C-w>")
map("i", "<C-h>", "<C-w>")
map("i", "<M-BS>", "<C-w>")

-- keep the selection after indenting
map("x", ">", ">gv")
map("x", "<", "<gv")

-- toggle comment with the built-in gc. gcc and gc are mappings themselves, so remap
map("n", "<C-/>", "gcc", { remap = true, desc = "Toggle comment" })
map("x", "<C-/>", "gcgv", { remap = true, desc = "Toggle comment" })
map("i", "<C-/>", "<Esc>gccgi", { remap = true, desc = "Toggle comment" })

-- lsp. nvim has the rest by default: K hover, grn rename, gra code action,
-- grr references, gri implementation, grt type, gO symbols, [d ]d diagnostics
map("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
map("n", "gD", vim.lsp.buf.declaration, { desc = "Go to declaration" })
map("n", "<leader>d", vim.diagnostic.setloclist, { desc = "Diagnostics of the buffer" })
map("n", "<leader>ih", function()
	vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
end, { desc = "Toggle inlay hints" })

-- run, build, check and test in a floating terminal
local function term(cmd)
	require("toggleterm").exec(cmd, 1, 15, nil, "float")
end

local function file()
	return vim.fn.shellescape(vim.fn.expand("%:p"))
end

local function stem()
	return vim.fn.shellescape(vim.fn.expand("%:t:r"))
end

local runners = {
	python = function()
		return "python3 " .. file()
	end,
	sh = function()
		return "bash " .. file()
	end,
	bash = function()
		return "bash " .. file()
	end,
	zsh = function()
		return "zsh " .. file()
	end,
	javascript = function()
		return "node " .. file()
	end,
	typescript = function()
		return "node " .. file()
	end,
	go = function()
		return "go run " .. file()
	end,
	rust = function()
		return "cargo run"
	end,
	c = function()
		return "gcc " .. file() .. " -o /tmp/" .. stem() .. " && /tmp/" .. stem()
	end,
	cpp = function()
		return "g++ " .. file() .. " -o /tmp/" .. stem() .. " && /tmp/" .. stem()
	end,
}

local builds = {
	python = "python3 -m compileall -q .",
	go = "go build ./...",
	rust = "cargo build",
	c = "make",
	cpp = "make",
}

local checks = {
	python = "ruff check .",
	go = "go vet ./...",
	rust = "cargo check",
	lua = "stylua --check .",
	nix = "nix-instantiate --parse .",
}

local tests = {
	python = "pytest -q",
	go = "go test ./...",
	rust = "cargo test",
}

local function task(tbl, name)
	local cmd = tbl[vim.bo.filetype]
	if not cmd then
		vim.notify("No " .. name .. " command for " .. vim.bo.filetype, vim.log.levels.WARN)
		return
	end
	term(cmd)
end

map("n", "<leader>xr", function()
	local run = runners[vim.bo.filetype]
	if not run then
		vim.notify("No runner for " .. vim.bo.filetype, vim.log.levels.WARN)
		return
	end
	term(run())
end, { desc = "Run file" })

map("n", "<leader>xb", function()
	task(builds, "build")
end, { desc = "Build project" })

map("n", "<leader>xc", function()
	task(checks, "check")
end, { desc = "Lint project" })

map("n", "<leader>xt", function()
	task(tests, "test")
end, { desc = "Test project" })

-- close the completion popup on click, then let the click through
for _, lhs in ipairs({ "<LeftMouse>", "<RightMouse>" }) do
	map("i", lhs, function()
		pcall(function()
			require("blink.cmp").hide()
		end)
		return lhs
	end, { expr = true, desc = "Close completion and click" })
end
