return {
	"nvim-neo-tree/neo-tree.nvim",
	branch = "v3.x",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"MunifTanjim/nui.nvim",
		"nvim-tree/nvim-web-devicons", -- optional, but recommended
	},
	lazy = false,                      -- neo-tree will lazily load itself
	config = function()
		vim.keymap.set("n", "<C-n>", ":Neotree filesystem reveal left<CR>")
		require("neo-tree").setup({
			enable_git_status = true,
			enable_diagnostics = true,
			filesystem = {
				use_libuv_file_watcher = true
			},
			git_status = {
				window = {
					position = "float",
					mappings = {
						["A"] = "git_add_all",
						["gu"] = "git_unstage_file",
						["gU"] = "git_undo_last_commit",
						["ga"] = "git_add_file",
						["gr"] = "git_revert_file",
						["gc"] = "git_commit",
						["gp"] = "git_push",
						["gg"] = "git_commit_and_push",
						["o"] = {
							"show_help",
							nowait = false,
							config = { title = "Order by", prefix_key = "o" },
						},
						["oc"] = { "order_by_created", nowait = false },
						["od"] = { "order_by_diagnostics", nowait = false },
						["om"] = { "order_by_modified", nowait = false },
						["on"] = { "order_by_name", nowait = false },
						["os"] = { "order_by_size", nowait = false },
						["ot"] = { "order_by_type", nowait = false },
					}
				}
			}
		})
	end
}
