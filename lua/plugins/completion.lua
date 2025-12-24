return {
	{
		"github/copilot.vim"
	},
	{
		"saghen/blink.cmp",
		version = "^1.8.0",
		opts = {
			signature = { enabled = true }
		}
	},
	-- {
	-- 	"ray-x/lsp_signature.nvim",
	-- 	event = "InsertEnter",
	-- 	opts = {
	-- 		close_timeout = 0,
	-- 		fix_pos = false,
	-- 		always_trigger = true
	-- 	}
	-- },
	-- {
	-- 	"hrsh7th/nvim-cmp",
	-- 	dependencies = {
	-- 		"hrsh7th/cmp-nvim-lsp",
	-- 		"hrsh7th/cmp-buffer",
	-- 		"hrsh7th/cmp-path",
	-- 		"L3MON4D3/LuaSnip",
	-- 		"saadparwaiz1/cmp_luasnip"
	-- 	},
	-- 	config = function()
	-- 		local cmp = require("cmp")
	-- 		local luasnip = require("luasnip")
	--
	-- 		cmp.setup({
	-- 			mapping = cmp.mapping.preset.insert({
	-- 				["<C-b>"] = cmp.mapping.scroll_docs(-4),
	-- 				["<C-f>"] = cmp.mapping.scroll_docs(4),
	-- 				["<C-Space>"] = cmp.mapping.complete(),
	-- 				["<C-e>"] = cmp.mapping.abort(),
	-- 				["<CR>"] = cmp.mapping.confirm({ select = true }),
	-- 				["<Tab>"] = cmp.mapping(function(fallback)
	-- 					if cmp.visible() then
	-- 						cmp.select_next_item()
	-- 					elseif luasnip.expand_or_jumpable() then
	-- 						luasnip.expand_or_jump()
	-- 					else
	-- 						fallback()
	-- 					end
	-- 				end, { "i", "s" }),
	-- 				["<S-Tab>"] = cmp.mapping(function(fallback)
	-- 					if cmp.visible() then
	-- 						cmp.select_prev_item()
	-- 					elseif luasnip.jumpable(-1) then
	-- 						luasnip.jump(-1)
	-- 					else
	-- 						fallback()
	-- 					end
	-- 				end, { "i", "s" })
	-- 			}),
	-- 			sources = cmp.config.sources({
	-- 				{ name = "nvim_lsp" },
	-- 				{ name = "luasnip" }
	-- 			}, {
	-- 				{ name = "buffer" },
	-- 				{ name = "path" }
	-- 			})
	-- 		})
	-- 	end
	-- }
}
