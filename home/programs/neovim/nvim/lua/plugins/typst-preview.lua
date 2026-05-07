return {
	"chomosuke/typst-preview.nvim",
	version = "1.*",
	cmd = { "TypstPreview", "TypstPreviewStop" },
	opts = {
		port = 8000,
		open_cmd = "qutebrowser %s",
	},
	keys = {
		{ "<leader>tp", "<cmd>TypstPreview<cr>", desc = "Typst preview" },
		{ "<leader>ts", "<cmd>TypstPreviewStop<cr>", desc = "Stop preview" },
	},
}
