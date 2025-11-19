return {
	"nvim-treesitter/nvim-treesitter",
	dependencies = {
		"nvim-treesitter/nvim-treesitter-textobjects"
	},
	build = ":TSUpdate",
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		require("nvim-treesitter.configs").setup({
			ensure_installed = { "lua", "c", "cpp", "rust", "java", "javascript" },

			sync_install = false,
			auto_install = true,

			highlight = { enable = true },
			indent = { enable = true },
			textobjects = {
				select = {
					enable = true,
					lookahead = true,
					keymaps = {
						["ia"] = "@parameter.inner",
						["aa"] = "@parameter.outer",
						["af"] = "@function.outer",
						["if"] = "@function.inner",
					},
				},
			},
		})
	end
}

