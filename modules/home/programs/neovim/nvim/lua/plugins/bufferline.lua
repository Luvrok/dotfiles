-- the open buffers at the top, like editor tabs. no backgrounds, the
-- current one is orange. starts right of neo-tree (offsets), above the
-- tree goes the project's path, neo-tree's own root line is hidden.
-- shown while a file or neo-tree is open, hidden on the dashboard
local colors = {
	accent = "#d65d0e",
	fg = "#ebdbb2",
	dim = "#928374",
}

return {
	"akinsho/bufferline.nvim",
	version = "*",
	event = "VeryLazy",
	keys = function()
		local keys = {
			{ "<A-Right>", "<cmd>BufferLineCycleNext<CR>", desc = "Next buffer" },
			{ "<A-Left>", "<cmd>BufferLineCyclePrev<CR>", desc = "Previous buffer" },
			{ "<A-S-Right>", "<cmd>BufferLineMoveNext<CR>", desc = "Move buffer right" },
			{ "<A-S-Left>", "<cmd>BufferLineMovePrev<CR>", desc = "Move buffer left" },
			{ "<A-p>", "<cmd>BufferLinePick<CR>", desc = "Pick buffer by letter" },
		}
		-- alt+1..9: the buffer at that place in the bar
		for i = 1, 9 do
			table.insert(
				keys,
				{ "<A-" .. i .. ">", "<cmd>BufferLineGoToBuffer " .. i .. "<CR>", desc = "Buffer " .. i }
			)
		end
		return keys
	end,
	init = function()
		-- the bar while a file is open (a listed buffer with a name, not the
		-- dashboard or an empty [No Name]) or neo-tree is, for its path
		local function update()
			local files = vim.tbl_filter(function(b)
				return b.name ~= "" and vim.bo[b.bufnr].buftype == ""
			end, vim.fn.getbufinfo({ buflisted = 1 }))
			local tree = vim.iter(vim.api.nvim_tabpage_list_wins(0)):any(function(w)
				return vim.bo[vim.api.nvim_win_get_buf(w)].filetype == "neo-tree"
			end)
			vim.o.showtabline = (#files > 0 or tree) and 2 or 0
		end
		vim.api.nvim_create_autocmd({
			"BufAdd",
			"BufDelete",
			"BufWipeout",
			"BufEnter",
			"BufFilePost",
			"BufWinEnter",
			"WinClosed",
			"TabEnter",
		}, {
			group = vim.api.nvim_create_augroup("user-bufferline", { clear = true }),
			-- a deleted buffer is still listed and a closed window still there
			-- during their events
			callback = vim.schedule_wrap(update),
		})
		update()
	end,
	opts = function()
		local hl = function(fg, extra)
			return vim.tbl_extend("force", { fg = fg, bg = "NONE" }, extra or {})
		end
		return {
			options = {
				mode = "buffers",
				-- the cycle wraps around: after the last one comes the first
				-- (bufferline's own order, the one on the screen)
				show_buffer_icons = false,
				show_buffer_close_icons = false,
				show_close_icon = false,
				show_tab_indicators = true,
				modified_icon = "●",
				separator_style = { "", "" },
				indicator = { style = "none" },
				diagnostics = false,
				-- bufferline shows itself from 2 buffers, here from 1 (below)
				always_show_bufferline = true,
				auto_toggle_bufferline = false,
				max_name_length = 24,
				-- no empty [No Name] in the bar, a new unsaved one with text stays
				custom_filter = function(buf)
					return vim.api.nvim_buf_get_name(buf) ~= "" or vim.bo[buf].modified
				end,
				tab_size = 0,
				-- the bar starts where neo-tree ends, nothing over the tree
				offsets = {
					{
						filetype = "neo-tree",
						text = function()
							return vim.fn.fnamemodify(vim.fn.getcwd(), ":~")
						end,
						text_align = "left",
						highlight = "NeoTreeRootName",
						separator = false,
					},
				},
				-- Snacks.bufdelete keeps the window (and neo-tree next to it)
				close_command = function(buf)
					Snacks.bufdelete(buf)
				end,
				right_mouse_command = function(buf)
					Snacks.bufdelete(buf)
				end,
			},
			highlights = {
				fill = hl(colors.dim),
				background = hl(colors.dim),
				buffer_visible = hl(colors.dim),
				buffer_selected = hl(colors.accent, { bold = true, italic = false }),
				modified = hl(colors.dim),
				modified_visible = hl(colors.dim),
				modified_selected = hl(colors.accent),
				duplicate = hl(colors.dim, { italic = false }),
				duplicate_visible = hl(colors.dim, { italic = false }),
				duplicate_selected = hl(colors.fg, { italic = false }),
				tab = hl(colors.dim),
				tab_selected = hl(colors.accent),
				tab_separator = hl(colors.dim),
				tab_separator_selected = hl(colors.dim),
				pick = hl(colors.accent, { bold = true, italic = false }),
				pick_visible = hl(colors.accent, { bold = true, italic = false }),
				pick_selected = hl(colors.accent, { bold = true, italic = false }),
				offset_separator = hl(colors.dim),
				separator = hl(colors.dim),
				separator_visible = hl(colors.dim),
				separator_selected = hl(colors.dim),
			},
		}
	end,
}
