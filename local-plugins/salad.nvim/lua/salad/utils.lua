local libuv = vim.uv or vim.loop
local config = require("salad.config")

local M = {}

---@type boolean
M.is_windows = libuv.os_uname().version:match("Windows")

---@param win integer
---@param options vim.api.keyset.win_config
function M.set_win_options(win, options)
	for k, v in pairs(options) do
		vim.api.nvim_set_option_value(k, v, { scope = "local", win = win })
	end
end

---@param path string
---@return integer|nil
function M.find_buffer(path)
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_get_name(bufnr) == path then
			return bufnr
		end
	end

	return nil
end

---@param root_path string
---@param expands table<string, boolean>
---@return string
function M.make_expands_key(root_path, expands)
	---@param path string
	---@return boolean
    local function is_visible(path)
        if path == root_path then
            return true
        end

        local parent = vim.fn.fnamemodify(path, ":h")
        while parent and parent ~= "" and parent ~= path do
            if M.slashed(parent) == M.slashed(root_path) then
                return true
            end

            if not expands[parent] then
                return false
            end

            local next_parent = vim.fn.fnamemodify(parent, ":h")
            if next_parent == parent then
				return false
			end

            parent = next_parent
        end

        return false
    end

    local expanded_paths = {}
    for path, is_expanded in pairs(expands) do
        if is_expanded and is_visible(path) then
            table.insert(expanded_paths, path)
        end
    end

    table.sort(expanded_paths)
    return table.concat(expanded_paths, "|")
end

---@param lines salad.TextChunk[][]
---@return string[]
---@return salad.Highlights[] highlights
function M.render_table(lines)
	local str_lines = {}
	local highlights = {}
	for _, cols in ipairs(lines) do
		local pieces = {}
		local col = 0
		for _, chunk in ipairs(cols) do
			local text, hl
			if type(chunk) == "string" then
				text = chunk
			else
				text = chunk[1]
				hl = chunk[2]
			end

			if text then
				table.insert(pieces, text)
				local col_end = col + text:len() + 1

				if hl then
					table.insert(highlights, { hl, #str_lines, col, col_end })
				end

				col = col_end
			end
		end

		table.insert(str_lines, table.concat(pieces, " "))
	end

	return str_lines, highlights
end

---@param bufnr integer
---@param actions table
function M.setup_keymaps(bufnr, actions)
	for name, keymaps in pairs(config.keymaps) do
		if actions[name] ~= nil then
			for _, keymap in ipairs(keymaps) do
				vim.keymap.set(keymap[1], keymap[2], actions[name], {
					buffer = bufnr
				})
			end
		else
			vim.print("no action named " .. name)
		end
	end
end

---@param path string
---@return boolean
function M.is_absolute(path)
	if M.is_windows then
		return path:match("^%a:\\")
	end

	return vim.startswith(path, "/")
end

---@param p string
---@return string[]
function M.split_path(p)
  local t = {}
  for comp in string.gmatch(p, "[^/]+") do
    table.insert(t, comp)
  end
  return t
end

---@param path string
---@param relative_to string
---@return string[]
function M.ascend_paths(path, relative_to)
    -- Normalize paths
    path = vim.fs.normalize(path)
    relative_to = vim.fs.normalize(relative_to)

    -- Split both paths
    local p = vim.split(path, "[/\\]", { trimempty = true })
    local r = vim.split(relative_to, "[/\\]", { trimempty = true })

    -- Ensure "relative_to" is a prefix of "path"
    for i = 1, #r do
        if p[i] ~= r[i] then
            return {}
        end
    end

    -- Build all paths from relative_to → target
    local out = {}
    local current = relative_to

    for i = #r + 1, #p do
        current = current .. "/" .. p[i]
        table.insert(out, current)
    end

    return out
end

---@param path string
---@return string
function M.os_to_posix_path(path)
	if M.is_windows then
		if M.is_absolute(path) then
			local drive, rem = path:match("^([^:]+):\\(.*)$")
			return string.format("/%s/%s", drive:upper(), rem:gsub("\\", "/"))
		end

		local new_path = path:gsub("\\", "/")
		return new_path
	end

	return path
end

---@param path string
---@return string
function M.posix_to_os_path(path)
	if M.is_windows then
		if vim.startswith(path, "/") then
			local drive = path:match("^/(%a+)")
			if not drive then
				local value = path:gsub("/", "\\")
				return value
			end

			local rem = path:sub(drive:len() + 2)
			return string.format("%s:%s", drive, rem:gsub("/", "\\"))
		end

		local new_path = path:gsub("/", "\\")
		return new_path
	end

	return path
end

---@param path string
---@param os_slash? boolean
---@return string
function M.slashed(path, os_slash)
	local slash = "/"
	if os_slash and M.is_windows then
		slash = "\\"
	end

	local endslash = path:match(slash .. "$")
	if not endslash then
		return path .. slash
	end

	return path
end

---@param path string
---@param parent string
---@return boolean
function M.is_child_of(path, parent)
	if M.is_windows then
		path = path:lower()
		parent = parent:lower()
	end

	parent = M.slashed(parent)
	return path:sub(1, #parent) == parent
end

---@param path string
---@param relative_to string
---@return string
function M.shorten(path, relative_to)
	if not M.is_child_of(path, relative_to) then
		return ""
	end

	return path:sub(1, #relative_to)
end

---@param root_path string
---@param path string
---@return integer
function M.get_depth(root_path, path)
	local rel = path:gsub("^" .. vim.pesc(root_path) .. "/?", "")
    local depth = 0
    if rel ~= path then
        -- count slashes in dirname
        local dirname = rel:match("(.+)/") -- everything except the last component
        if dirname then
            depth = select(2, dirname:gsub("/", "")) + 1
        end
    end

	return depth
end

---@param path string
---@return string
function M.get_filename(path)
	local filename = path:match("([^/]+)$")
	return filename
end

---@param url string
---@return string|nil scheme
---@return string|nil path
function M.parse_url(url)
	return url:match("^(.*://)(.*)$")
end

---@param dir? string
---@return string
function M.get_url_for_path(dir)
	if dir then
		local scheme = M.parse_url(dir)
		if scheme then
			return dir
		end

		local abs_path = vim.fn.fnamemodify(dir, ":p")
		local path = M.os_to_posix_path(abs_path)
		return config.drivers.files .. path
	end

	local bufname = vim.api.nvim_buf_get_name(0)
	local scheme = M.parse_url(bufname)

	if not scheme then
		local cwd = M.os_to_posix_path(vim.fn.getcwd())
		local buf_path = M.os_to_posix_path(vim.fn.fnamemodify(bufname, ":p:h"))
		local parent

		if bufname == "" or M.is_child_of(buf_path, cwd) then
			parent = M.os_to_posix_path(cwd)
		else
			parent = M.os_to_posix_path(buf_path)
		end

		return M.slashed(config.drivers.files .. parent)
	end

	return bufname
end

return M
