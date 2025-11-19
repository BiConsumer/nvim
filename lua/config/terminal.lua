local state = {
	terminals = {},
	floating = {
		window = -1,
		buffer = -1
	},
	hidden = false
}

local function create_floating_terminal(opts)
	local width = opts.width or math.floor(vim.o.columns * 0.8)
	local height = opts.height or math.floor(vim.o.lines * 0.8)

	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	local buf = nil
	if vim.api.nvim_buf_is_valid(opts.buf) then
		buf = opts.buf
	else
		buf = vim.api.nvim_create_buf(false, true)
	end

	local win_config = {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		style = "minimal",
		border = "rounded",
	}

	local win = vim.api.nvim_open_win(buf, true, win_config)
	state.floating.window = win
	state.floating.buffer = buf

	if vim.bo[buf].buftype ~= "terminal" then
		vim.cmd.terminal()
	end
end

local function toggle_floating_terminal()
	if not vim.api.nvim_win_is_valid(state.floating.window) then
		create_floating_terminal({ buf = state.floating.buffer })
	else
		vim.api.nvim_win_hide(state.floating.window)
	end
end

local function create_terminal(split)
	if split == "v" then
		vim.cmd.vsplit()
		vim.cmd.wincmd("h")
	else
		vim.cmd.split()
		vim.cmd.wincmd("j")
	end

	vim.cmd.terminal()
	vim.api.nvim_win_set_height(0, 10)

	table.insert(state.terminals, {
		split = split,
		window = vim.api.nvim_get_current_win(),
		buffer = vim.api.nvim_get_current_buf()
	})
end

local function toggle_terminals()
	state.hidden = not state.hidden

	-- hide terminals
	if state.hidden then
		for _, terminal in ipairs(state.terminals) do
			if vim.api.nvim_win_is_valid(terminal.window) then
				vim.api.nvim_win_hide(terminal.window)
			end
		end
		return
	end

	-- show terminals
	for _, terminal in ipairs(state.terminals) do
		if vim.api.nvim_buf_is_valid(terminal.buffer) then
			if terminal.split == "v" then
				vim.cmd.vsplit()
				vim.cmd.wincmd("h")
			else
				vim.cmd.split()
				vim.cmd.wincmd("j")
			end

			vim.api.nvim_win_set_buf(0, terminal.buffer)
			vim.api.nvim_win_set_height(0, 10)
			terminal.window = vim.api.nvim_get_current_win()
		end
	end
end

vim.keymap.set("n", "<leader>ft", toggle_floating_terminal)
vim.keymap.set("n", "<leader>tt", toggle_terminals)
vim.keymap.set("n", "<leader>ts", function()
	create_terminal()
end)

vim.keymap.set("n", "<leader>tvs", function()
	create_terminal("v")
end)

vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>")
