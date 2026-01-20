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

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("flex_treesitter", { clear = true }),
			callback = function(ev)
				local lang = vim.treesitter.language.get_lang(ev.match)

				local function enabled(feat)
					local f = opts[feat] or {}
					return f.enable ~= false
						and not (type(f.disable) == "table" and vim.tbl_contains(f.disable, lang))
				end

				-- highlighting
				if enabled("highlight") then
					pcall(vim.treesitter.start, ev.buf)
				end
			end,
		})
	end,
}
