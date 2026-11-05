-- the open buffers at the top, one box each: a dark box with a gap of the
-- terminal's own background between them, the current one lighter with
-- an orange name. starts right of neo-tree (offsets), above the tree goes
-- the project's path, neo-tree's own root line is hidden.
-- shown while a file or neo-tree is open, hidden on the dashboard
local colors = {
	accent = "#d65d0e",
	fg = "#ebdbb2",
	dim = "#928374",
	-- the boxes: light enough to show on the editor's background, or a tab
	-- that isn't the current one has no box at all
	box = "#2b2b2b",
	box_selected = "#3c3836",
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

		-- a blank line under the bar: a winbar of one space in every file
		-- window (not floats, not the tree, the dashboard or terminals).
		-- transparent like the rest, WinBar links to StatusLine otherwise
		local spacer = " "
		local function pad(win)
			if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_win_get_config(win).relative ~= "" then
				return
			end
			if vim.bo[vim.api.nvim_win_get_buf(win)].buftype == "" then
				vim.wo[win].winbar = spacer
			elseif vim.wo[win].winbar == spacer then
				vim.wo[win].winbar = ""
			end
		end
		local function clear_hl()
			vim.api.nvim_set_hl(0, "WinBar", { bg = "NONE" })
			vim.api.nvim_set_hl(0, "WinBarNC", { bg = "NONE" })
		end
		clear_hl()
		local group = vim.api.nvim_create_augroup("user-winbar-spacer", { clear = true })
		vim.api.nvim_create_autocmd("ColorScheme", { group = group, callback = clear_hl })
		vim.api.nvim_create_autocmd({ "WinNew", "WinEnter", "BufWinEnter" }, {
			group = group,
			callback = function()
				pad(vim.api.nvim_get_current_win())
			end,
		})
	end,
	opts = function()
		-- bg NONE is the gap and the empty rest of the bar, a box has its own
		local hl = function(fg, extra)
			return vim.tbl_extend("force", { fg = fg, bg = "NONE" }, extra or {})
		end
		local box = function(fg, extra)
			return vim.tbl_extend("force", { fg = fg, bg = colors.box }, extra or {})
		end
		local selected = function(fg, extra)
			return vim.tbl_extend("force", { fg = fg, bg = colors.box_selected }, extra or {})
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
				-- a space before each box is the gap, bg NONE (separator below)
				separator_style = { " ", "" },
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
				background = box(colors.dim),
				buffer_visible = box(colors.dim),
				buffer_selected = selected(colors.accent, { bold = true, italic = false }),
				modified = box(colors.dim),
				modified_visible = box(colors.dim),
				modified_selected = selected(colors.accent),
				duplicate = box(colors.dim, { italic = false }),
				duplicate_visible = box(colors.dim, { italic = false }),
				duplicate_selected = selected(colors.fg, { italic = false }),
				tab = box(colors.dim),
				tab_selected = selected(colors.accent),
				tab_separator = hl(colors.dim),
				tab_separator_selected = hl(colors.dim),
				pick = box(colors.accent, { bold = true, italic = false }),
				pick_visible = box(colors.accent, { bold = true, italic = false }),
				pick_selected = selected(colors.accent, { bold = true, italic = false }),
				offset_separator = hl(colors.dim),
				separator = hl(colors.dim),
				separator_visible = hl(colors.dim),
				separator_selected = hl(colors.dim),
			},
		}
	end,
}
