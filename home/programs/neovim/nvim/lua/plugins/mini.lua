return {
	{
		"nvim-mini/mini.nvim",
		version = "*",
		config = function()
			require("mini.pairs").setup({ modes = { command = true } })
		end,
	},
}
