return {
	"rachartier/tiny-code-action.nvim",
    dependencies = {
        {"nvim-lua/plenary.nvim"},
        {"nvim-telescope/telescope.nvim"},
    },
    event = "LspAttach", 
    opts = {
		backend = "vim",
		picker = "telescope"
	},
	config = function()
		local action = require("tiny-code-action")
		vim.keymap.set({ "n", "x" }, "<leader>ca", function()
			action.code_action()
		end, { noremap = true, silent = true })
	end
}

