local libuv = vim.uv or vim.loop
local utils = require("salad.utils")
local entries_cache = require("salad.entries")
local config = require("salad.config")

local FIELD_CHILDREN = entries_cache.FIELD_CHILDREN
local FIELD_LINK = entries_cache.FIELD_LINK

local M = {}

---@param url string
---@param expands table<string, boolean>
---@param callback fun(err?: string, root_entry?: salad.Entry)
function M.list(url, expands, callback)
	local scheme, root_path = utils.parse_url(url)
	assert(scheme)
	assert(root_path)

	if utils.is_windows and root_path == "/" then
		---TODO: list drives
		error("haven't implemented windows drives list yet, :c")
	end

	local pending = 0
	local finished = false
	local root_entry = entries_cache.create_and_store_entry(scheme, root_path, "directory")

	local function finish()
		if finished or pending ~= 0 then
			return
		end

		finished = true
		callback(nil, root_entry)
	end

	---@param path string
	---@param link_callback fun(link: string, link_stat: uv.fs_stat.result)
	local function read_link(path, link_callback)
		pending = pending + 1

		local os_path = utils.posix_to_os_path(path)
		libuv.fs_readlink(os_path, function(link_err, link)
			if link_err then
				return callback(link_err)
			end

			assert(link)
			libuv.fs_stat(link, function(stat_err, stat)
				if stat_err then
					return callback(stat_err)
				end

				assert(stat)
				link_callback(link, stat)
				pending = pending - 1
				finish()
			end)
		end)
	end

	---@param path string
	---@param parent_entry salad.Entry
	---@param depth? integer
	local function scan(path, parent_entry, depth)
		pending = pending + 1
		depth = depth or 1

		local os_path = utils.posix_to_os_path(path)
		libuv.fs_opendir(os_path, function(open_err, dir)
			if open_err then
				if open_err:match("^ENOENT: no such file or directory") then
					pending = pending - 1
					return finish()
				else
					pending = pending - 1
					return callback(open_err)
				end
			end

			local function read_next()
				libuv.fs_readdir(dir, function(err, dir_entries)
					if err then
						libuv.fs_closedir(dir, function()
							callback(err)
						end)

						pending = pending - 1
						return
					end

					if not dir_entries then
						libuv.fs_closedir(dir, function(close_err)
							if close_err then
								callback(close_err)
							end
						end)

						pending = pending - 1
						return finish()
					end

					---@type salad.Entry[]
					for _, dir_entry in ipairs(dir_entries) do
						local dir_entry_path = utils.slashed(path) .. dir_entry.name
						local cache_entry = entries_cache.create_and_store_entry(scheme, dir_entry_path, dir_entry.type)
						parent_entry[FIELD_CHILDREN][dir_entry_path] = cache_entry

						if dir_entry.type == "link" then
							read_link(dir_entry_path, function(link, link_stat)
								local posix_link = utils.os_to_posix_path(link)
								cache_entry[FIELD_LINK] = {
									link = posix_link,
									type = link_stat.type
								}

								if link_stat.type == "directory" and expands[dir_entry_path] then
									scan(posix_link, cache_entry, depth + 1)
								end
							end)
						end

						-- recursively list directories
						if dir_entry.type == "directory" and expands[dir_entry_path] then
							scan(dir_entry_path, cache_entry, depth + 1)
						end
					end

					read_next()
				end)
			end

			read_next()
		end, config.read_batch_size)

	end

	scan(root_path, root_entry)
end

---@param path string
---@param callback fun()
---@return fun()
function M.watch_changes(path, callback)
	local uv_event = assert(libuv.new_fs_event())
	uv_event:start(utils.posix_to_os_path(path), { recursive = true }, vim.schedule_wrap(function(err, _, _)
		if err then
			return
		end

		callback()
	end))

	return function()
		uv_event:stop()
	end
end

return M

