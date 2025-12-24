return {
	"nvim-telescope/telescope.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		require("telescope").setup({
			defaults = {
				layout_config = {
					horizontal = { width = 0.9 },
				},
				preview = {
					treesitter = {
						enable = true,
						disable = { "cpp" }
					}
				},
				path_display = { "filename_first" }
			}
		})

		local builtin = require("telescope.builtin")
		vim.keymap.set("n", "<leader>ff", builtin.find_files, { desc = "Telescope find files" })
		vim.keymap.set("n", "<leader>fg", builtin.live_grep, { desc = "Telescope live grep" })
		vim.keymap.set("n", "<leader>fb", builtin.buffers, { desc = "Telescope buffers" })
		vim.keymap.set("n", "<leader>fh", builtin.help_tags, { desc = "Telescope help tags" })
		vim.keymap.set("n", "<leader>ds", builtin.lsp_document_symbols, { desc = "Telescope document symbols" })
		vim.keymap.set("n", "<leader>dd", builtin.diagnostics, { desc = "Telescope diagnostics" })

		-- Previewer additions
		-- vim.api.nvim_create_autocmd("User", {
		-- 	pattern = "TelescopePreviewerLoaded",
		-- 	callback = function(args)
		-- 		local bufnr = args.buf
		-- 		local filetype = args.data.filetype
		-- 		local bufname = args.data.bufname
		--
		-- 		if filetype ~= "cpp" then
		-- 			return
		-- 		end
		--
		-- 		-- check if file is already loaded
		-- 		local existed = false
		-- 		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		-- 			if vim.api.nvim_buf_is_loaded(buf) and vim.api.nvim_buf_get_name(buf) == bufname then
		-- 				for _, win in pairs(vim.api.nvim_list_wins()) do
		-- 					if vim.api.nvim_win_get_buf(win) == bufnr then
		-- 						vim.api.nvim_win_set_buf(win, buf)
		-- 						vim.print(vim.wo[win].winhl)
		-- 						vim.wo[win].winhl = vim.wo[win].winhl
		--
		-- 						return
		-- 					end
		-- 				end
		--
		-- 				break
		-- 			end
		-- 		end
		--
		-- 		vim.bo[bufnr].filetype = filetype
		-- 		vim.api.nvim_buf_set_name(bufnr, bufname)
		--
		-- 		for _, client in pairs(vim.lsp.get_clients()) do
		-- 			if client.config.filetypes and vim.tbl_contains(client.config.filetypes, filetype) then
		-- 				vim.lsp.buf_attach_client(bufnr, client.id)
		-- 				vim.lsp.semantic_tokens.start(bufnr, client.id)
		-- 			end
		-- 		end
		-- 	end
		-- })
	end
}
