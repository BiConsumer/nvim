local M = {}

---@class (exact) salad.Driver
---@field name string
---@field list fun(path: string, expands: table<string, boolean>, callback: fun(err: string?, root_entry?: salad.Entry)) 
---@field watch_changes fun(path: string, callback: fun()): fun()

---@param setup_opts? salad.SetupOptions
function M.setup(setup_opts)
	local config = require("salad.config")
	config.setup(setup_opts)
	vim.api.nvim_create_augroup("salad", {})
end

return M

