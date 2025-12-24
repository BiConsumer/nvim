return {
	{
		"catppuccin/nvim", name = "catppuccin", priority = 1000
	},
	{
		"rebelot/kanagawa.nvim",
		priority = 1000,
		lazy = false,
		config = function()
			vim.cmd.colorscheme "kanagawa-dragon"
			vim.opt.cursorline = true
		end
	}
}

