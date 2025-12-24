return {
	"neovim/nvim-lspconfig",
	dependencies = {
		{
			"Civitasv/cmake-tools.nvim",
			opts = {},
			config = function()
				require("cmake-tools").setup({
					cmake_compile_commands_options = {
						action = "copy"
					}
				})
			end
		},
		"hrsh7th/nvim-cmp",
		"nvim-java/nvim-java"
	},
	config = function()
		vim.api.nvim_create_autocmd("LspAttach", {
			callback = function(args)
				local client = vim.lsp.get_client_by_id(args.data.client_id)

				-- keymaps
				local opts = { noremap = true, silent = true, buffer = args.buf }
				vim.keymap.set("n", "gd", vim.lsp.buf.declaration, opts)
				vim.keymap.set("n", "gD", vim.lsp.buf.definition, opts)
				vim.keymap.set("n", "gr", vim.lsp.buf.references, opts)
				vim.keymap.set('n', '<leader>d', vim.diagnostic.open_float, opts)

				if not client then
					return
				end

				-- if client.server_capabilities.semanticTokensProvider then
				-- 	vim.lsp.semantic_tokens.start(args.buf, args.data.client_id)
				-- end

				-- cursor highlight
				if client:supports_method("textDocument/documentHighlight") then
					local group = vim.api.nvim_create_augroup("lsp_document_highlight", { clear = true })

					vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
						group = group,
						buffer = args.buf,
						callback = function()
							vim.lsp.buf.clear_references()
							vim.lsp.buf.document_highlight()
						end
					})
				end
			end
		})

		-- local capabilities = require("cmp_nvim_lsp").default_capabilities()
		vim.lsp.config("lua_ls", {
			settings = {
				Lua = {
					hint = { enable = true },
					runtime = { version = "LuaJIT" },
					diagnostics = { globals = { "vim" } },
					workspace = {
						library = {
							vim.fn.stdpath("config"),
							vim.fn.expand("$VIMRUNTIME/lua"),
							vim.fn.stdpath("data") .. "/lazy/lazy.nvim/lua/lazy",
							"${3rd}/luv/library"
						},
						checkThirdParty = false,
					},
				},
			},
		})

		require("java").setup()
		vim.lsp.config("jdtls", {
			settings = {
				java = {
					configuration = {
						runtimes = {
							{
								name = "JavaSDK-21",
								path = "C:\\Program Files\\Java\\jdk-21"
							},
						},
					},
				},
			},
		})

		vim.lsp.config("jsonls", {})
		vim.lsp.config("neocmake", {})
		vim.lsp.config("clangd", {
			cmd = { "clangd", "--fallback-style=none", "--background-index", "--clang-tidy" }
		})

		vim.lsp.config("glsl_analyzer", {})
		vim.filetype.add({
			extension = {
				vsh = "glsl",
				fsh = "glsl"
			}
		})

		vim.lsp.config("rust_analyzer", {})
		vim.lsp.config("tsserver", {})
		vim.lsp.config("gdscript", {})
		vim.lsp.config("roslyn_ls", {})
		vim.lsp.enable({ "lua_ls", "jdtls", "jsonls", "neocmake", "clangd", "glsl_analyzer", "rust_analyzer", "tsserver",
			"gdscript", "roslyn_ls" })

		-- lsp cpp highlight groups
		vim.api.nvim_set_hl(0, "cStructure", { link = "Keyword" })
		vim.api.nvim_set_hl(0, "cDefine", { link = "Keyword" })
		vim.api.nvim_set_hl(0, "cPreCondit", { link = "Keyword" })
		vim.api.nvim_set_hl(0, "cStorageClass", { fg = "#d94d43" })

		vim.api.nvim_set_hl(0, "cppPointer", { fg = "#ed7539" })
		vim.api.nvim_set_hl(0, "cppReference", { fg = "#ed7539" })
		vim.api.nvim_set_hl(0, "cppScope", { fg = "#c96fa5" })
		vim.api.nvim_set_hl(0, "cppAttribute", { fg = "#c586c0" })
		vim.api.nvim_set_hl(0, "cppDocComment", { fg = "#548761", italic = true })

		vim.api.nvim_set_hl(0, "cppStructure", { link = "Keyword" })
		vim.api.nvim_set_hl(0, "cppAccess", { link = "Keyword" })
		vim.api.nvim_set_hl(0, "cppStorageClass", { fg = "#d94d43" })
		vim.api.nvim_set_hl(0, "cppModifier", { fg = "#d94d43" })

		vim.api.nvim_set_hl(0, "@lsp.type.namespace.cpp", { fg = "#59718f" })
		vim.api.nvim_set_hl(0, "@lsp.type.modifier.cpp", { link = "cppModifier" })
		vim.api.nvim_set_hl(0, "@lsp.type.concept.cpp", { fg = "#429989" })
		vim.api.nvim_set_hl(0, "@lsp.type.typeParameter.cpp", { fg = "#6987b8" })
		vim.api.nvim_set_hl(0, "@lsp.mod.constructorOrDestructor.cpp", { link = "Keyword" })

		-- diagnostic config
		vim.api.nvim_set_hl(0, "DiagnosticNumError", { link = "DiagnosticError" })
		vim.api.nvim_set_hl(0, "DiagnosticNumWarn", { link = "DiagnosticWarn" })
		vim.api.nvim_set_hl(0, "DiagnosticNumInfo", { link = "DiagnosticInfo" })
		vim.api.nvim_set_hl(0, "DiagnosticNumHint", { link = "DiagnosticHint" })

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
