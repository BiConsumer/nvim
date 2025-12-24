return {
	{ "nvim-tree/nvim-web-devicons", opts = {} },
	{
		"NStefan002/screenkey.nvim",
		lazy = false,
		version = "*", -- or branch = "main", to use the latest commit
	},
	{
		"kylechui/nvim-surround",
		version = "^3.0.0",
		event = "VeryLazy",
		config = function()
			require("nvim-surround").setup({})
		end
	},
	{
		"nvim-mini/mini.files",
		config = function()
			local minifiles = require("mini.files")
			minifiles.setup({
				mappings = {
					go_in = "<CR>",
					go_out = "<BS>",
					reset = "`"
				}
			})

			vim.keymap.set("n", "<leader>mf", function()
				minifiles.open(vim.api.nvim_buf_get_name(0))
			end)
		end
	},

	-- local plugins
	{
		{
			dir = vim.fn.stdpath("config") .. "/local-plugins/rename.nvim",
			config = function()
				local rename = require("rename")
				rename.setup()
				vim.keymap.set("n", "<leader>rn", rename.live_rename)
			end
		},
		{
			dir = vim.fn.stdpath("config") .. "/local-plugins/salad.nvim",
			dependencies = {
				"nvim-mini/mini.icons"
			},
			config = function()
				require("salad").setup()

				local salad_view = require("salad.view")
				vim.keymap.set("n", "<leader>sl", salad_view.open)
			end
		}
	}
}
