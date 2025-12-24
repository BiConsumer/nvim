local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local previewers = require("telescope.previewers")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")
local conf = require("telescope.config").values

local function open_rename_menu(items, new_name)

end

return {
	open_rename_menu = open_rename_menu
}

