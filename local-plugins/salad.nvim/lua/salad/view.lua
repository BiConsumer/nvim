local config = require("salad.config")
local utils = require("salad.utils")
local layout = require("salad.layout")
local entries_cache = require("salad.entries")

local FIELD_ID = entries_cache.FIELD_ID
local FIELD_PATH = entries_cache.FIELD_PATH
local FIELD_TYPE = entries_cache.FIELD_TYPE
local FIELD_CHILDREN = entries_cache.FIELD_CHILDREN
local FIELD_LINK = entries_cache.FIELD_LINK

local EXTMARKS_NS = vim.api.nvim_create_namespace("salad.extmarks")

local M = {}
local actions = {}

---@class (exact) salad.ViewOpenOptions
---@field jump? boolean

---@class (exact) salad.BufInitializeOpts
---@field seek_path? string
---@field topline? integer
---@field expands? table<string, boolean>
---@field ignore_cache? boolean

---@alias salad.HlTuple { [1]: string, [2]: string }
---@alias salad.Extmark { [1]: string, [2]: string, [3]: integer } virt_text, hl_group, col
---@alias salad.Highlights { [1]: string, [2]: integer, [3]: integer, [4]: integer }
---@alias salad.TextChunk string|salad.HlTuple

---@class (exact) salad.ViewNode
---@field entry salad.Entry
---@field open boolean
---@field depth integer

---@class (exact) salad.ViewData
---@field url string
---@field nodes table<integer, salad.ViewNode>
---@field expands table<string, boolean>

---@type table<integer, salad.ViewData>
local session = {}

--- url -> expands_key -> bufnr
---@type table<string, table<string, integer>>
local session_by_expand = {}

---@type table<string, fun()>
local url_file_events = {}

---@param url string
---@param expands_key string
---@return integer|nil
local function get_view_from_expands(url, expands_key)
	local url_sessions = session_by_expand[url]
	if not url_sessions then
		return nil
	end

	return url_sessions[expands_key]
end

---@param path string
---@param root_path string
---@return table<string, boolean> expands
local function expands_from_path(path, root_path)
	local expands = {}
	for _, expand_path in ipairs(utils.ascend_paths(path, root_path)) do
		expands[expand_path] = true
	end

	return expands
end

---@param root_path string
---@param expands table<string, boolean>
---@return string
local function make_expands_key(root_path, expands)
	---@param path string
	---@return boolean
    local function is_visible(path)
        if path == root_path then
            return true
        end

        local parent = vim.fn.fnamemodify(path, ":h")
        while parent and parent ~= "" and parent ~= path do
            if utils.slashed(parent) == utils.slashed(root_path) then
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

---@param entries salad.Entry[]
---@return salad.Entry[]
local function sort_entries(entries)
	table.sort(entries, function(a, b)
		local a_is_dir = a[FIELD_TYPE] == "directory"
        local b_is_dir = b[FIELD_TYPE] == "directory"

        if a_is_dir ~= b_is_dir then
            return a_is_dir
        end

        return a[FIELD_PATH] < b[FIELD_PATH]
	end)

	return entries
end

---@param root_entry salad.Entry
---@param view_data salad.ViewData
---@return salad.ViewNode[]
local function flatten_entry(root_entry, view_data)
	local result = {}

	---@param parent salad.ViewNode
	---@param depth? integer
	local function recurse(parent, depth)
		depth = depth or 0
		local sorted = sort_entries(vim.tbl_values(parent[FIELD_CHILDREN]))
		for _, entry in ipairs(sorted) do
			local open = entry[FIELD_TYPE] == "directory" and view_data.expands[entry[FIELD_PATH]]
			local node = {
				entry = entry,
				depth = depth,
				open = open
			}

			view_data.nodes[entry[FIELD_ID]] = node
			table.insert(result, node)

			if open then
				recurse(entry, depth + 1)
			end
		end
	end

	recurse(root_entry)
	return result
end

function M.get_all_buffers()
	return vim.tbl_filter(vim.api.nvim_buf_is_loaded, vim.tbl_keys(session))
end

function M.lock_buffers()
	for bufnr in pairs(session) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			vim.bo[bufnr].modifiable = false
		end
	end
end

function M.unlock_buffers()
	for bufnr in pairs(session) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			vim.bo[bufnr].modifiable = true
		end
	end
end

---@return integer[]|nil visible
---@return integer[]|nil hidden
local function get_visible_hidden_buffers()
	local buffers = M.get_all_buffers()
	local hidden = {}
	for _, bufnr in ipairs(buffers) do
		if vim.bo[bufnr].modified then
			return
		end

		hidden[bufnr] = true
	end

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		if vim.api.nvim_win_is_valid(win) then
			hidden[vim.api.nvim_win_get_buf(win)] = nil
		end
	end

	local visible = vim.tbl_filter(function(bufnr)
		return not hidden[bufnr]
	end, buffers)
	return visible, vim.tbl_keys(hidden)
end

local function delete_hidden_buffers()
	local visible, hidden = get_visible_hidden_buffers()
	if not visible or not hidden or not vim.tbl_isempty(visible) then
		return
	end

	vim.print("deleting bufs")
	for _, bufnr in ipairs(hidden) do
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end

	for _, stop_watcher in pairs(url_file_events) do
		stop_watcher()
	end

	session = {}
	session_by_expand = {}
	url_file_events = {}
	entries_cache.clear()
end

function actions.focus()
	local bufnr = vim.api.nvim_get_current_buf()
	if vim.b[bufnr].salad_loading then
		return
	end

	local view_data = session[bufnr]
	if not view_data then
		return
	end

	if vim.bo[bufnr].modified then
		return vim.notify("Cannot focus when there are unsaved changes", vim.log.levels.WARN)
	end

	local line = vim.api.nvim_get_current_line()
	local id = assert(entries_cache.parse_line(line))
	local entry = assert(entries_cache.get_entry_by_id(id))

	local lnum = vim.fn.line(".")
	local start_entry_path = entry[FIELD_PATH]
	while entry[FIELD_TYPE] ~= "directory" or (entry[FIELD_PATH] ~= start_entry_path and not entry[FIELD_CHILDREN][start_entry_path]) do
		lnum = lnum - 1
		if lnum == 0 then
			break
		end

		line = vim.fn.getline(lnum)
		id = assert(entries_cache.parse_line(line))
		entry = assert(entries_cache.get_entry_by_id(id))
	end

	if entry[FIELD_TYPE] ~= "directory" or (entry[FIELD_PATH] ~= start_entry_path and not entry[FIELD_CHILDREN][start_entry_path]) then
		return vim.notify("Could not find directory to focus at cursor", vim.log.levels.WARN)
	end

	local scheme = utils.parse_url(view_data.url)
	assert(scheme)

	local expands_key = make_expands_key(entry[FIELD_PATH], view_data.expands)
	local new_url = scheme .. entry[FIELD_PATH]
	local new_bufnr = get_view_from_expands(new_url, expands_key)
	if not new_bufnr or not vim.api.nvim_buf_is_valid(new_bufnr) then
		new_bufnr = vim.api.nvim_create_buf(false, true)
	end

	vim.api.nvim_set_current_buf(new_bufnr)
	M.initialize(new_bufnr, new_url, {
		expands = view_data.expands,
		seek_path = start_entry_path
	})
	utils.set_win_options(vim.api.nvim_get_current_win(), config.view_options.win_options)
end

function actions.show_parent()
	local bufnr = vim.api.nvim_get_current_buf()
	if vim.b[bufnr].salad_loading then
		return
	end

	local view_data = session[bufnr]
	if not view_data then
		return
	end

	if vim.bo[bufnr].modified then
		return vim.notify("Cannot show parent when there are unsaved changes", vim.log.levels.WARN)
	end

	local line = vim.api.nvim_get_current_line()
	local id = assert(entries_cache.parse_line(line))
	local entry = assert(entries_cache.get_entry_by_id(id))
	local scheme, path = utils.parse_url(view_data.url)
	assert(scheme)
	assert(path)

	local parent = vim.fn.fnamemodify(path, ":h")
	local expands_key = make_expands_key(parent, view_data.expands)
	local new_url = scheme .. parent
	local new_bufnr = get_view_from_expands(new_url, expands_key)
	if not new_bufnr or not vim.api.nvim_buf_is_valid(new_bufnr) then
		new_bufnr = vim.api.nvim_create_buf(false, true)
	end

	vim.api.nvim_set_current_buf(new_bufnr)
	M.initialize(new_bufnr, new_url, {
		expands = view_data.expands,
		seek_path = entry[FIELD_PATH]
	})
	utils.set_win_options(vim.api.nvim_get_current_win(), config.view_options.win_options)
end

function actions.close()
	local bufnr = vim.api.nvim_get_current_buf()
	if vim.b[bufnr].salad_loading then
		return
	end

	local view_data = session[bufnr]
	if not view_data then
		return
	end

	vim.api.nvim_win_close(0, false)
end

function actions.select()
	local bufnr = vim.api.nvim_get_current_buf()
	if vim.b[bufnr].salad_loading then
		return
	end

	local view_data = session[bufnr]
	if not view_data then
		return
	end

	local line = vim.api.nvim_get_current_line()
	local id = entries_cache.parse_line(line)
	if not id then
		return
	end

	local entry = entries_cache.get_entry_by_id(id)
	if not entry then
		return
	end

	local path = entry[FIELD_PATH]
	local link = entry[FIELD_LINK]
	if entry[FIELD_TYPE] ~= "directory" and (not link or link.type ~="directory") then
		local last_win = vim.fn.win_getid(vim.fn.winnr("#"))
		if not vim.api.nvim_win_is_valid(last_win) then
			last_win = vim.api.nvim_get_current_win()
		end

		-- TODO: use driver for this
		local os_path = utils.posix_to_os_path(path)
		local file_bufnr = utils.find_buffer(os_path)
		if file_bufnr then
			vim.api.nvim_win_set_buf(last_win, file_bufnr)
			return
		end

		local current_win = vim.api.nvim_get_current_win()
		vim.api.nvim_set_current_win(last_win)
		vim.cmd("e " .. os_path)
		vim.api.nvim_set_current_win(current_win)
		return
	end

	local url = view_data.url
	local _, root_path = utils.parse_url(url)
	assert(root_path)

	local expands = vim.deepcopy(view_data.expands)
	expands[path] = not expands[path]
	if link then
		expands[link] = not expands[link]
	end

	local view = vim.fn.winsaveview()
	local expands_key = make_expands_key(root_path, expands)

	local new_bufnr = get_view_from_expands(url, expands_key)
	if not new_bufnr or not vim.api.nvim_buf_is_valid(new_bufnr) then
		new_bufnr = vim.api.nvim_create_buf(false, true)
	end

	vim.api.nvim_set_current_buf(new_bufnr)
	M.initialize(new_bufnr, url, {
		expands = expands,
		seek_path = path,
		topline = view.topline
	})

	utils.set_win_options(vim.api.nvim_get_current_win(), config.view_options.win_options)
end

---@param path string
---@return boolean display
---@return boolean is_hidden
local function should_display(path)
	if config.view_options.is_always_hidden(path) then
		return false, true
	end

	local is_hidden = config.view_options.is_hidden_file(path)
	local display = config.view_options.show_hidden or not is_hidden
	return display, is_hidden
end

---@param node salad.ViewNode
---@param is_hidden boolean
---@return salad.TextChunk[] text
---@return salad.Extmark[] marks
local function format_col(node, is_hidden)
	local cols = {}
	local marks = {}

	local path = node.entry[FIELD_PATH]
	local id = node.entry[FIELD_ID]
	local type = node.entry[FIELD_TYPE]
	local link = node.entry[FIELD_LINK]
	if link then
		type = link.type
	end

	local id_fmt = entries_cache.format_id(id)
	table.insert(cols, id_fmt)

	local indent = config.view_options.indent * node.depth - 1
	if type ~= "directory" then
		indent = indent + 2
	end

	if indent > 0 then
		table.insert(cols, string.rep(" ", indent))
	end

	if type == "directory" then
		table.insert(cols, node.open and config.view_options.glyphs.arrow_open or config.view_options.glyphs.arrow_closed)
	end

	local icon, hl = config.view_options.icon_for_file(path, type)
	table.insert(cols, { icon, hl })

	local name = utils.get_filename(path)
	table.insert(cols, name)
	if link then
		table.insert(cols, "-> " .. link.link)
	end

	-- we can now insert extmarks for git and lsp status
	return cols, marks
end

---@param bufnr integer
---@param nodes salad.ViewNode[]
---@param opts? salad.BufInitializeOpts
local function render_buffer(bufnr, nodes, opts)
	opts = opts or {}
	local lines = {}
	local line_marks = {}
	local jmp_idx

	for _, node in ipairs(nodes) do
		local path = node.entry[FIELD_PATH]
		local display, is_hidden = should_display(path)
		if display then
			local cols, cols_marks = format_col(node, is_hidden)

			table.insert(line_marks, cols_marks)
			table.insert(lines, cols)

			if path == opts.seek_path then
				jmp_idx = #lines
			end
		end
	end

	local lines_raw, highlights = utils.render_table(lines)
	vim.bo[bufnr].modifiable = true
	vim.bo[bufnr].undolevels = -1
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, true, lines_raw)
	vim.bo[bufnr].undolevels = vim.api.nvim_get_option_value("undolevels", { scope = "global" })
	vim.bo[bufnr].modified = false

	vim.api.nvim_buf_clear_namespace(bufnr, EXTMARKS_NS, 0, -1)
	for _, highlight in ipairs(highlights) do
		local group, line, col_start, col_end = unpack(highlight)
		vim.api.nvim_buf_set_extmark(bufnr, EXTMARKS_NS, line, col_start, {
			end_col = col_end,
			hl_group = group,
			strict = false
		})
	end

	for line, cols_marks in ipairs(line_marks) do
		for _, mark in ipairs(cols_marks) do
			vim.api.nvim_buf_set_extmark(bufnr, EXTMARKS_NS, line - 1, mark[3], {
				virt_text = { { mark[1], mark[2] } },
				virt_text_pos = "inline",
				invalidate = true
			})
		end
	end

	if jmp_idx or opts.topline then
		for _, win in ipairs(vim.api.nvim_list_wins()) do
			if vim.api.nvim_win_get_buf(win) == bufnr then
				if jmp_idx then
					vim.api.nvim_win_set_cursor(win, { jmp_idx, 0 })
				end

				if opts.topline then
					vim.api.nvim_win_call(win, function()
						vim.fn.winrestview({ topline = opts.topline })
					end)
				end

				break
			end
		end
	end
end

---@param url string
---@param bufnr integer
---@param opts? salad.BufInitializeOpts
local function render_buffer_async(url, bufnr, opts)
	local scheme, path = utils.parse_url(url)
	assert(scheme)
	assert(path)

	local driver = assert(config.get_driver_by_scheme(scheme))

	-- TODO: loading ui visual
	vim.b[bufnr].salad_loading = true
	vim.bo[bufnr].modifiable = false

	driver.list(url, session[bufnr].expands, function(err, root_entry)
		if not vim.b[bufnr].salad_loading then
			return
		end

		if err then
			vim.b[bufnr].salad_loading = false
			return error(err)
		end

		if not root_entry then
			return error("no root entry?")
		end

		vim.b[bufnr].salad_loading = false
		vim.schedule(function()
			if not vim.api.nvim_buf_is_valid(bufnr) then
				return
			end

			local nodes = flatten_entry(root_entry, session[bufnr])
			vim.print("rendering buffer " .. tostring(#nodes))
			render_buffer(bufnr, nodes, opts)
		end)
	end)
end

---@param bufnr integer
---@param url string
---@param opts? salad.BufInitializeOpts
function M.initialize(bufnr, url, opts)
	if bufnr == 0 then
		bufnr = vim.api.nvim_get_current_buf()
	end

	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	local scheme, path = utils.parse_url(url)
	if not scheme or not path then
		return error(string.format("malformed url", url))
	end

	local driver = config.get_driver_by_scheme(scheme)
	if not driver then
		return vim.notify_once(
			string.format("[salad] could not find driver for url '%s'", url),
			vim.log.levels.ERROR
		)
	end

	opts = opts or {}
	vim.bo[bufnr].filetype = "salad"
	vim.bo[bufnr].syntax = "salad"
	vim.bo[bufnr].buftype = "acwrite"
	vim.bo[bufnr].swapfile = false
	vim.bo[bufnr].bufhidden = "hide"
	vim.bo[bufnr].buflisted = false

	local existed = session[bufnr] ~= nil
	session[bufnr] = session[bufnr] or {
		url = url,
		nodes = {},
		expands = {}
	}

	session[bufnr].url = url
	if opts.expands then
		session[bufnr].expands = opts.expands
	end

	local expands_key = make_expands_key(path, session[bufnr].expands)
	session_by_expand[url] = session_by_expand[url] or {}
	session_by_expand[url][expands_key] = bufnr

	-- if not url_file_events[url] then
	-- 	url_file_events[url] = driver.watch_changes(path, function()
	-- 		entries_cache.get_entry_by_path(scheme, path)[FIELD_CHILDREN] = {}
	-- 		local buffers = vim.tbl_values(session_by_expand[url])
	-- 		for _, url_buf in ipairs(buffers) do
	-- 			if not vim.api.nvim_buf_is_valid(url_buf) then
	-- 				return
	-- 			end
	--
	-- 			if vim.bo[url_buf].modified or vim.b[url_buf].salad_dirty then
	-- 				return
	-- 			end
	--
	-- 			--- TODO: check if we are applying some changes
	--
	-- 			for _, win in ipairs(vim.api.nvim_list_wins()) do
	-- 				if vim.api.nvim_win_is_valid(win) and vim.api.nvim_win_get_buf(win) == url_buf then
	-- 					return render_buffer_async(url, url_buf, { ignore_cache = true })
	-- 				end
	-- 			end
	--
	-- 			vim.b[url_buf].salad_dirty = { ignore_cache = true }
	-- 		end
	-- 	end)
	-- end

	vim.api.nvim_clear_autocmds({
		buffer = bufnr,
		group = "salad"
	})

	-- refresh on re-enter
	vim.api.nvim_create_autocmd("BufEnter", {
		group = "salad",
		buffer = bufnr,
		callback = function()
			local dirty_opts = vim.b[bufnr].salad_dirty
			if not dirty_opts then
				return
			end

			vim.b[bufnr].salad_dirty = nil
			render_buffer_async(url, bufnr, dirty_opts)
		end
	})

	-- clear salad buffers when none are visible
	vim.api.nvim_create_autocmd("BufHidden", {
		group = "salad",
		buffer = bufnr,
		callback = function()
			vim.defer_fn(function()
				local visible = get_visible_hidden_buffers()
				if visible and vim.tbl_isempty(visible) then
					delete_hidden_buffers()
				end
			end, 100)
		end
	})

	-- TODO: constraint cursor events

	utils.setup_keymaps(bufnr, actions)
	if existed and not opts.ignore_cache then
		vim.print("using cache")
		local root_entry = entries_cache.get_entry_by_path(scheme, path)
		assert(root_entry)

		local nodes = flatten_entry(root_entry, session[bufnr])
		return render_buffer(bufnr, nodes, opts)
	end

	vim.print("not cache")
	render_buffer_async(url, bufnr, opts)
end

---@param dir? string
---@param opts? salad.ViewOpenOptions
function M.open(dir, opts)
	opts = opts or {
		jump = true
	}

	local url = utils.get_url_for_path(dir)
	local _, path = utils.parse_url(url)
	if not path then
		return
	end

	local bufname = vim.api.nvim_buf_get_name(0)
	local buf_path = bufname ~= "" and utils.os_to_posix_path(bufname) or ""

	local expands = expands_from_path(buf_path, path)
	local expands_key = make_expands_key(path, expands)
	local bufnr = get_view_from_expands(url, expands_key)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		bufnr = vim.api.nvim_create_buf(false, true)
	end

	-- make window
	local win_config = layout.get_fullscreen_win_config()
	local win = vim.api.nvim_open_win(bufnr, true, win_config)
	vim.wo[win].winhl = "Normal:Normal,NormalNC:Normal,FloatBorder:Normal"
	utils.set_win_options(win, config.view_options.win_options)
	vim.api.nvim_set_current_win(win)

	-- setup listeners

	M.initialize(bufnr, url, {
		expands = expands,
		seek_path = opts.jump and buf_path or nil
	})
end

return M
