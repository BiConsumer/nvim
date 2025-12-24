local DEFAULT_CONFIG = {
	lsp_file_methods = {
		enabled = true,
		timeout_ms = 1000
	},
	watch_changes = true,
	read_batch_size = 1024,
	keymaps = {
		select = {
			{ "n", "<CR>" }
		},
		close = {
			{ "n", "q" },
			{ "n", "<ESC>" }
		},
		focus = {
			{ "n", "<leader>f" }
		},
		show_parent = {
			{ "n", "<leader>sp" }
		},
		go_cwd = {
			{ "n", "<leader>gc" }
		}
	},
	drivers = {
		files = "salad://",
		ssh = "salad-ssh://"
	},
	view_options = {
		show_hidden = true,
		show_diagnostics = true,
		indent = 2,
		glyphs = {
			arrow_closed = "",
			arrow_open = ""
		},
		win_options = {
			wrap = false,
			signcolumn = "no",
			foldcolumn = "0",
			spell = false,
			list = false,
			conceallevel = 3,
			concealcursor = "nvic"
		},
		should_expand = function(depth)
			return depth == 0
		end,
		is_always_hidden = function(_)
			return false
		end,
		is_hidden_file = function(path)
			local match = path:match("(^%.)") or path:match("(/%.)")
			return match ~= nil
		end,
		highlight_filename = function()

		end,
		icon_for_file = function(path, type)
			local has_devicons, devicons = pcall(require, "mini.icons")
			if not has_devicons then
				return
			end

			local icon, hl = devicons.get(type, path)
			icon = icon or ""
			return icon, hl
		end
	}
}

---@class salad.Config
---@field lsp_file_methods salad.LspFileMethods
---@field watch_changes boolean
---@field read_batch_size integer
---@field keymaps salad.Keymaps
---@field view_options salad.ViewOptions
---@field drivers salad.DriversConfig
local M = {}

---@class (exact) salad.SetupOptions
---@field lsp_file_methods? salad.LspFileMethods
---@field watch_changes? boolean
---@field read_batch_size? integer
---@field keymaps? salad.Keymaps
---@field view_options? salad.ViewOptions
---@field drivers? salad.DriversConfig

---@class (exact) salad.LspFileMethods
---@field enabled boolean
---@field timeout_ms integer

---@alias salad.Keymap {[1]: string, [2]: string}[]
---@class (exact) salad.Keymaps
---@field select salad.Keymap
---@field close salad.Keymap
---@field focus salad.Keymap
---@field show_parent salad.Keymap
---@field go_cwd salad.Keymap

---@class (exact) salad.ViewOptions
---@field show_hidden boolean
---@field show_diagnostics boolean
---@field indent integer
---@field glyphs salad.ViewOptions.Glyphs
---@field win_options table<string, any>
---@field should_expand fun(depth: integer): boolean
---@field highlight_filename fun(name: string, bufnr: integer): boolean
---@field icon_for_file fun(path: string, type: salad.EntryType): string|nil, string|nil
---@field is_hidden_file fun(path: string): boolean
---@field is_always_hidden fun(path: string): boolean

---@class (exact) salad.ViewOptions.Glyphs
---@field arrow_open string
---@field arrow_closed string

---@class (exact) salad.DriversConfig
---@field files string
---@field ssh string

---@param setup_options? salad.SetupOptions
function M.setup(setup_options)
	setup_options = setup_options or {}
	local new_conf = vim.tbl_extend("keep", setup_options, DEFAULT_CONFIG)
	for k, v in pairs(new_conf) do
		M[k] = v
	end

	M._drivers_by_scheme = {}
	M._drivers_cache = {}
	for driver, scheme in pairs(M.drivers) do
		M._drivers_by_scheme[scheme] = driver
	end
end

---@param scheme? string
---@return salad.Driver|nil
function M.get_driver_by_scheme(scheme)
	if not scheme then
		return nil
	end

	if not vim.endswith(scheme, "://") then
		local pieces = vim.split(scheme, "://", { plain = true })
		if #pieces <= 2 then
			scheme = pieces[1] .. "://"
		else
			error(string.format("Malformed url: '%s'", scheme))
			return nil
		end
	end

	local name = M._drivers_by_scheme[scheme]
	if not name then
		return nil
	end

	local driver = M._drivers_cache[name]
	if driver == nil then
		local ok
		ok, driver = pcall(require, string.format("salad.drivers.%s", name))

		if ok then
			M._drivers_cache[name] = driver
		else
			M._drivers_cache[name] = false
			driver = false
		end
	end

	return driver and driver or nil
end

return M

