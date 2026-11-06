-- the chat in the editor talks to the same opencode service as the terminal
-- and the desktop app: the model, the agents, the skills and the permissions
-- are the config in modules/home/programs/opencode. ask sends the cursor or
-- the selection as the context (@this), so the file the buffer shows is what
-- the question is about, and the project stays editable through the usual
-- tools. saved files are what opencode reads, save before asking
return {
	"nickjvandyke/opencode.nvim",
	-- no version: main is the branch that speaks the v2 server api
	keys = {
		{
			"<leader>a",
			function()
				require("opencode").ask("@this: ")
			end,
			mode = { "n", "x" },
			desc = "Ask OpenCode about this",
		},
		{
			"<leader>A",
			function()
				require("opencode").select()
			end,
			mode = { "n", "x" },
			desc = "OpenCode menu",
		},
	},
	config = function()
		-- snacks.input and snacks.picker do the ask and the select
		vim.g.opencode_opts = {}
	end,
}
