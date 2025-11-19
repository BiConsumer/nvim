return {
	"neovim/nvim-lspconfig",
	dependencies = {
		{
			"Civitasv/cmake-tools.nvim",
			opts = {},
			config = function ()
				require("cmake-tools").setup({
					cmake_compile_commands_options = {
						action = "copy"
					}
				})
			end
		},
		"hrsh7th/nvim-cmp"
	},
	config = function()
		vim.api.nvim_create_autocmd("LspAttach", {
			callback = function(args)
				local client = vim.lsp.get_client_by_id(args.data.client_id)

				-- keymaps
				local opts = { noremap = true, silent = true, buffer = args.buf  }
				vim.keymap.set("n", "gd", vim.lsp.buf.declaration, opts)
				vim.keymap.set("n", "gD", vim.lsp.buf.definition, opts)
				vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)

				if not client then
					return
				end

				-- cursor highlight
				if client:supports_method("textDocument/documentHighlight") then
					local group = vim.api.nvim_create_augroup("lsp_document_highlight", { clear = true })

					vim.api.nvim_create_autocmd({"CursorMoved", "CursorMovedI"}, {
						group = group,
						buffer = args.buf,
						callback = function ()
							vim.lsp.buf.clear_references()
							vim.lsp.buf.document_highlight()
						end
					})
				end
			end
		})

		local capabilities = require("cmp_nvim_lsp").default_capabilities()
		vim.lsp.config("*", {
			capabilities = capabilities,
			on_init = function(client, _)
				if client:supports_method("textDocument/semanticTokens") then
					client.server_capabilities.semanticTokensProvider = nil
				end
			end
		})

    	vim.lsp.config("lua_ls", {
		  settings = {
			Lua = {
			  runtime = { version = "LuaJIT" },
			  diagnostics = { globals = { "vim" } },
			  workspace = {
				library = {
				  vim.fn.expand("$VIMRUNTIME/lua"),
				  vim.fn.stdpath("data") .. "/lazy/lazy.nvim/lua/lazy",
				},
				checkThirdParty = false,
			  },
			},
		  },
		})
		vim.lsp.config("jsonls", {})
		vim.lsp.config("clangd", {})
		vim.lsp.config("rust_analyzer", {})
		vim.lsp.config("tsserver", {})
		vim.lsp.enable({"lua_ls", "jsonls", "clangd", "rust_analyzer", "tsserver"})

		-- diagnostic config
		vim.api.nvim_set_hl(0, "DiagnosticNumError", { link = "DiagnosticError" })
		vim.api.nvim_set_hl(0, "DiagnosticNumWarn",  { link = "DiagnosticWarn"  })
		vim.api.nvim_set_hl(0, "DiagnosticNumInfo",  { link = "DiagnosticInfo"  })
		vim.api.nvim_set_hl(0, "DiagnosticNumHint",  { link = "DiagnosticHint"  })

		local x = vim.diagnostic.severity
		vim.diagnostic.config({
			update_in_insert = true,
			virtual_text = {
				prefix = "",
				enabled = true,
			},
			signs = {
				text = {
					[x.ERROR] = "󰅙",
					[x.WARN] = "",
					[x.INFO] = "󰋼",
					[x.HINT] = "󰌵"
				},
				numhl = {
					[x.ERROR] = "DiagnosticNumError",
					[x.WARN]  = "DiagnosticNumWarn",
					[x.INFO]  = "DiagnosticNumInfo",
					[x.HINT]  = "DiagnosticNumHint",
				}
			},
			underline = true,
			float = {
				border = "single"
			}
		})
	end
}

