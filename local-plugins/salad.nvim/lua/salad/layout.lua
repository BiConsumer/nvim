local M = {}

---@return integer
function M.get_editor_width()
	return vim.o.columns
end

---@return integer
function M.get_editor_height()
	local height = vim.o.lines - vim.o.cmdheight
	-- Subtract 1 if tabline is visible
	if vim.o.showtabline == 2 or (vim.o.showtabline == 1 and #vim.api.nvim_list_tabpages() > 1) then
		height = height - 1
	end

	-- Subtract 1 if statusline is visible
	if
		vim.o.laststatus >= 2 or (vim.o.laststatus == 1 and #vim.api.nvim_tabpage_list_wins(0) > 1)
	then
		height = height - 1
	end

	return height
end

---@return vim.api.keyset.win_config
function M.get_fullscreen_win_config()
	local total_width = M.get_editor_width()
	local total_height = M.get_editor_height()

	local width = math.floor(total_width * 0.8)
	local height = math.floor(total_height * 0.8)

	local col = math.floor((total_width - width) / 2)
	local row = math.floor((total_height - height) / 2)

	return {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		border = {
			{ "┌", "FloatBorder" },
			{ "─", "FloatBorder" },
			{ "┐", "FloatBorder" },
			{ "│", "FloatBorder" },
			{ "┘", "FloatBorder" },
			{ "─", "FloatBorder" },
			{ "└", "FloatBorder" },
			{ "│", "FloatBorder" },
		},
		zindex = 45
	}
end

return M
