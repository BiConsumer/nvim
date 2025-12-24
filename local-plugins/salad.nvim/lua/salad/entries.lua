local M = {}

---@alias salad.Entry {[1]: integer, [2]: string, [3]: salad.EntryType, [4]: table<string, salad.Entry>, [5]: salad.Link|nil}

---@class (exact) salad.Link
---@field link string
---@field type salad.EntryType

---@alias salad.EntryType
---| "file"
---| "directory"
---| "link"

M.FIELD_ID = 1
M.FIELD_PATH = 2
M.FIELD_TYPE = 3
M.FIELD_CHILDREN = 4
M.FIELD_LINK = 5

local FIELD_ID = M.FIELD_ID
local FIELD_PATH = M.FIELD_PATH
local FIELD_CHILDREN = M.FIELD_CHILDREN

--- scheme -> path -> entry
---@type table<string, table<string, salad.Entry>>
local entries_by_path = {}

---@type table<integer, salad.Entry>
local entries_by_id = {}

---@type table<integer, string>
local trash = {}

---@type integer
local next_id = 1

function M.clear()
	if not vim.tbl_isempty(trash) then
		return
	end

	next_id = 1
	entries_by_path = {}
	entries_by_id = {}
	trash = {}
end

---@param id integer
---@return string
function M.format_id(id)
	return "/" .. id
end

---@param 	line string
---@return number|nil id
function M.parse_line(line)
	local value = line:match("^/(%d+) (.+)$")
	if not value then
		return nil
	end

	return tonumber(value)
end

---@param scheme string
---@param path string
---@param type salad.EntryType
---@return salad.Entry
function M.create_entry(scheme, path, type)
	local entry = entries_by_path[scheme] and entries_by_path[scheme][path] or nil
	if entry then
		return entry
	end

	return { nil, path, type, {}, nil }
end

---@param scheme string
---@param entry salad.Entry
function M.store_entry(scheme, entry)
	local id = entry[FIELD_ID]
	if id == nil then
		id = next_id
		next_id = next_id + 1
		entry[FIELD_ID] = id
	end

	local path = entry[FIELD_PATH]
	entries_by_path[scheme] = entries_by_path[scheme] or {}
	entries_by_path[scheme][path] = entry
	entries_by_id[id] = entry
end

---@param scheme string
---@param path string
---@param type salad.EntryType
---@return salad.Entry
function M.create_and_store_entry(scheme, path, type)
	local entry = M.create_entry(scheme, path, type)
	M.store_entry(scheme, entry)
	return entry
end

---@param id integer
---@return salad.Entry|nil
function M.get_entry_by_id(id)
	return entries_by_id[id]
end

---@param scheme string
---@param path string 
---@return salad.Entry|nil
function M.get_entry_by_path(scheme, path)
	return entries_by_path[scheme] and entries_by_path[scheme][path] or nil
end

return M

