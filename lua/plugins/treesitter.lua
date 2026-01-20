return {
	"nvim-treesitter/nvim-treesitter",
	branch = "main",
	lazy = false,
	build = ":TSUpdate",
	dependencies = {
		-- "nvim-treesitter/nvim-treesitter-textobjects",
	},
	opts = {
		ensure_installed = { "lua", "c", "cpp", "rust", "java", "javascript", "gdscript", "gdshader", "godot_resource", "c_sharp" },

		sync_install = false,
		auto_install = true,

		highlight = {
			enable = true,
			disable = { "c", "cpp" }
		},

		indent = { enable = false },
		textobjects = {
			select = {
				enable = true,
				lookahead = true,
				keymaps = {
					["ia"] = "@parameter.inner",
					["aa"] = "@parameter.outer",
					["af"] = "@function.outer",
					["if"] = "@function.inner",
				}
			}
		}
	},
	config = function(_, opts)
		require("nvim-treesitter").setup(opts)
	end,
}
