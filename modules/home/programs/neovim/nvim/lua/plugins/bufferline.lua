-- the open buffers at the top, like editor tabs. no backgrounds, the
-- current one is orange. starts right of neo-tree (offsets), the line
-- above the tree stays empty
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
				always_show_bufferline = true,
				max_name_length = 24,
				tab_size = 0,
				-- the bar starts where neo-tree ends, nothing over the tree
				offsets = {
					{ filetype = "neo-tree", text = "", highlight = "BufferLineFill", separator = false },
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
