return {
    "akinsho/bufferline.nvim",
    version = "*", 
    dependencies = "nvim-tree/nvim-web-devicons",
    config = function()
	vim.opt.termguicolors = true
	require("bufferline").setup({
	    options = {
		numbers = "ordinal",
		mode = "buffers",
		offsets = {
		    {
 		        filetype = "neo-tree",
		        text = "File Explorer",
		        text_align = "center",
		        separator = true
		    }
		},
		separator_style = "slope",
		diagnostics = "nvim_lisp",
	    }
	})

	--keymaps
	-- navigation
	vim.keymap.set("n", "<Tab>", ":BufferLineCycleNext<CR>")
	vim.keymap.set("n", "<s-Tab>", ":BufferLineCyclePrev<CR>")

	--closing
	vim.keymap.set("n", "<leader>bo", ":BufferLineCloseOthers<CR>")
	vim.keymap.set("n", "<leader>q", function()
  	    local bufs = vim.fn.getbufinfo({ buflisted = 1 })
  	    if #bufs > 1 then
    	        vim.cmd("BufferLineCycleNext")
    	        vim.cmd("bdelete #")
  	    else
    	        vim.cmd("bdelete")
  	    end
	end, { desc = "Close current buffer and go to next" })
    end
}

