-- the same titles and window size for every telescope picker
local M = {}

M.titles = { prompt_title = "search", results_title = "files", preview_title = "preview" }

function M.width(_, max_columns)
	if max_columns < 100 then
		return math.floor(max_columns * 0.95)
	elseif max_columns < 140 then
		return math.floor(max_columns * 0.85)
	end
	return math.min(math.floor(max_columns * 0.78), 160)
end

function M.height(_, _, max_lines)
	if max_lines < 30 then
		return math.floor(max_lines * 0.9)
	end
	return math.min(math.floor(max_lines * 0.85), 42)
end

-- opts with the titles, `results` renames the results window
local function with(opts, results)
	return vim.tbl_extend("force", M.titles, results and { results_title = results } or {}, opts or {})
end

function M.files(opts)
	require("telescope.builtin").find_files(with(opts))
end

function M.grep(opts)
	require("telescope.builtin").live_grep(with(opts))
end

function M.recent(opts)
	require("telescope.builtin").oldfiles(with(opts))
end

function M.projects(opts)
	require("telescope").extensions.projects.projects(with(opts, "projects"))
end

return M
