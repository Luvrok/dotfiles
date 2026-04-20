return {
	"sphamba/smear-cursor.nvim",
	lazy = false,
	opts = {
		smear_between_buffers = false,
		smear_between_neighbor_lines = true,
		scroll_buffer_space = true,
		legacy_computing_symbols_support = true,
		smear_insert_mode = true,

		stiffness = 0.45,
		trailing_stiffness = 0.45,
		matrix_pixel_threshold = 0.45,

		cursor_color = "#ebdbb2",
		transparent_bg_fallback_color = "#282828",
	},
}
