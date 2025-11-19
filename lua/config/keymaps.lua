vim.g.mapleader = " "
local map = vim.keymap.set

map("n", "<leader>td", function()
	vim.diagnostic.enable(not vim.diagnostic.is_enabled())
end)

