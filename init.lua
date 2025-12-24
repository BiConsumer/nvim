vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "nvim_treesitter#foldexpr()"
vim.opt.foldtext = ""
vim.opt.foldlevel = 99
vim.opt.fillchars = {
	vert = "▕", -- alternatives │
	fold = " ",
	eob = " ", -- suppress ~ at EndOfBuffer
	diff = "╱", -- alternatives = ⣿ ░ ─
	msgsep = "‾",
	foldopen = "▾",
	foldsep = "│",
	foldclose = "▸",
}

require("config.lazy")
require("config.keymaps")
require("config.terminal")

vim.api.nvim_create_user_command("DiffOrig", function()
	vim.cmd("vert new")
	vim.cmd("set bt=nofile")
	vim.cmd("r ++edit #")
	vim.cmd("0d_")
	vim.cmd("diffthis")
	vim.cmd("wincmd p")
	vim.cmd("diffthis")
end, {})

vim.api.nvim_create_user_command("LspFormatFolder", function(opts)
	local dir = opts.args ~= "" and opts.args or vim.fn.getcwd()

	local files = vim.fn.systemlist(
		'rg --files ' .. vim.fn.shellescape(dir)
	)

	for _, file in ipairs(files) do
		vim.cmd("edit " .. vim.fn.fnameescape(file))
		vim.lsp.buf.format({ async = false })
		vim.cmd("write")
		vim.cmd("bdelete")
	end
end, { nargs = "?" })

vim.fn.serverstart([[\\.\pipe\nvim-server]])
