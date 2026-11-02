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
-- commands are gone: splits are :vsp and :sp
map("n", "<C-t>", "<cmd>tabnew<CR>")
map("n", "<C-w>", "<cmd>bd<CR>", { desc = "Close buffer" })
map("n", "<A-Right>", "<cmd>bnext<CR>")
map("n", "<A-Left>", "<cmd>bprevious<CR>")

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
