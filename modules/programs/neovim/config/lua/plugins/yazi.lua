return {
	"mikavilpas/yazi.nvim",
	version = "*",
	event = "VeryLazy",
	dependencies = {
		{ "nvim-lua/plenary.nvim", lazy = true },
	},
	opts = {
		change_neovim_cwd_on_close = false,
		keymaps = {
			change_working_directory = false, -- отключаем дефолтный <c-\>
		},
		set_keymappings_function = function(buffer, config, context)
			vim.keymap.set("t", "<c-e>", function()
				require("yazi.keybinding_helpers").select_current_file_and_close_yazi(config, {
					api = context.api,
					on_file_opened = function(chosen_file)
						if not chosen_file or chosen_file == "" then
							return
						end
						local dir = vim.fn.fnamemodify(chosen_file, ":h")
						vim.cmd.cd(dir)
						vim.notify("cwd: " .. dir)
					end,
				})
			end, { buffer = buffer, desc = "cd here and close yazi" })
		end,
	},
	keys = {
		{
			"<leader>r",
			mode = { "n", "v" },
			"<cmd>Yazi<cr>",
			desc = "Open yazi at the current file",
		},
	},
}
