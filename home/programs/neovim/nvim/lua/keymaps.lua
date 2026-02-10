local map = vim.keymap.set

-- Undo / Redo в NORMAL режиме
map("n", "<C-z>", "u", { noremap = true, silent = true })
map("n", "<C-y>", "<C-r>", { noremap = true, silent = true })

-- Undo / Redo в INSERT режиме
map("i", "<C-z>", "<C-o>u", { noremap = true, silent = true })
map("i", "<C-y>", "<C-o><C-r>", { noremap = true, silent = true })

-- nothing to do
map("v", "<C-z>", "<Nop>", { noremap = true, silent = true })

-- Window navigation
map('n', '<C-h>', '<C-w><C-h>', opts)
map('n', '<C-l>', '<C-w><C-l>', opts)
map('n', '<C-j>', '<C-w><C-j>', opts)
map('n', '<C-k>', '<C-w><C-k>', opts)

-- Clipboard
map("n", "<C-c>", '"+y', opts)
map("n", "<C-x>", '"+d', opts)
map("x", "<C-c>", '"+ygv', opts)
map("x", "<C-x>", '"+dgv', opts)
map({ "n", "x" }, "<C-v>", '"+p', opts)
map("i", "<C-v>", "<C-r>+", opts)

-- Buffers and tabs
map("n", "<C-t>", ":tabnew<CR>", opts)
map("n", "<C-w>", ":bd<CR>", opts)
map("n", "<A-Right>", ":bnext<CR>", opts)
map("n", "<A-Left>", ":bprevious<CR>", opts)

-- Search and diagnostics
map('n', '<Esc>', '<cmd>nohlsearch<CR>', opts)

-- Delete words with CTRL-Backspace/Alt-Backspace in insert mode
map("i", "<C-BS>", "<C-w>", { silent = true })
map("i", "<C-h>",  "<C-w>", { silent = true })
map("i", "<M-BS>", "<C-w>", { silent = true })

-- Disable annoying stuff with q
map({ "n", "v" }, "q", "<Nop>", { silent = true })

-- Disable annoying visual-blocks mode
map({ "i", "n", "v" }, "<C-q>", "<Nop>", { silent = true })

map({ "n", "i", "v" }, "<C-s>", function()
  vim.cmd("silent w")
end, opts)

-- Keep visual selection after indenting
map("v", ">", ">gv")
map("v", "<", "<gv")

-- shift scroll
map({ "n", "i", "v" }, "<S-ScrollWheelUp>", "zh", { noremap = true, silent = true })
map({ "n", "i", "v" }, "<S-ScrollWheelDown>", "zl", { noremap = true, silent = true })
