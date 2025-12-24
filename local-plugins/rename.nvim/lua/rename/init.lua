local M = {}

local REFERENCES_METHOD = "textDocument/references"
local PREP_RENAME_METHOD = "textDocument/prepareRename"
local RENAME_METHOD = "textDocument/rename"

local EXTMARK_NS = vim.api.nvim_create_namespace("user.util.input.extmark")
local WIN_HL_NS = vim.api.nvim_create_namespace("user.util.input.win_hl")
local BUF_HL_NS = vim.api.nvim_create_namespace("user.util.input.buf_hl")

local config = {
	request_timeout = 1500,
	highlights = {
		current = "CurSearch",
		others = "Search"
	},
	mappings = {
		submit = {
			{ "n", "<CR>" },
			{ "v", "<CR>" },
			{ "i", "<CR>" }
		},
		cancel = {
			{ "n", "<Esc>" }
		}
	}
}

local state = {
	transaction_id = -1,
	extmark_id = -1,
	input_buf = -1,
	input_win = -1,
	current_buf = -1,
	current_win = -1,
	prev_conceal = 0,
	new_text = "",
	references = {},
	cword = {
		line = -1,
		start_col = -1,
		end_col = -1,
		text = "",
		initial_offset = -1
	}
}

local function notify_error(message, err)
    if err then
        local err_msg
        if type(err) == "string" then
            err_msg = err
        elseif type(err) == "table" and err.message and type(err.message) == "string" then
            err_msg = err.message
        else
            err_msg = vim.inspect(err)
        end

        message = string.format("%s: `%s`", message, err_msg)
    end

    vim.notify(message, vim.log.levels.ERROR, { title = "live-rename" })
end

local function range_to_cols(client, buf, range)
	local start_col = vim.lsp.util._get_line_byte_from_position(buf, range.start, client.offset_encoding)
    local end_col = vim.lsp.util._get_line_byte_from_position(buf, range["end"], client.offset_encoding)
    return start_col, end_col
end

local function input_update()
	state.new_text = vim.api.nvim_buf_get_lines(state.input_buf, 0, 1, false)[1]
	local text_width = vim.fn.strdisplaywidth(state.new_text)

	vim.api.nvim_buf_set_extmark(state.current_buf, EXTMARK_NS, state.cword.line, state.cword.start_col, {
		id = state.extmark_id,
		end_col = state.cword.end_col,
		virt_text_pos = "inline",
		virt_text = { { string.rep(" ", text_width), config.highlights.current } },
		conceal = "",
	})

	-- show edit for other references
	for _, reference in ipairs(state.references) do
		vim.api.nvim_buf_set_extmark(reference.buf, EXTMARK_NS, reference.line, reference.start_col, {
			id = reference.extmark_id,
			end_col = reference.end_col,
			virt_text_pos = "inline",
			virt_text = { { state.new_text, config.highlights.others } },
			conceal = ""
		})
	end

	vim.api.nvim_buf_clear_namespace(state.input_buf, BUF_HL_NS, 0, -1)
	vim.api.nvim_buf_set_extmark(state.input_buf, BUF_HL_NS, 0, 0, {
		end_col = #state.new_text,
		hl_group = config.highlights.current
	})

	-- avoid line wrapping
	vim.api.nvim_win_set_width(state.input_win, text_width + 2)
end

local function fetch_references(client, current_buf, position_params, transaction_id)
	local params = {
		textDocument = position_params.textDocument,
		position = position_params.position,
		context = { includeDeclaration = true }
	}

	vim.lsp.buf_request(current_buf, REFERENCES_METHOD, params, function(err, result, _, _)
		if state.transaction_id ~= transaction_id then
			return
		end

		if err then
			notify_error("[lsp-rename] error finding references", err)
			return
		elseif not result or vim.tbl_isempty(result) then
			notify_error("[lsp-rename] nothing to rename")
			return
		end

		local win_offset = 0
		for _, location in ipairs(result) do
			local range = location.range
			local line = range.start.line
			local buf = vim.uri_to_bufnr(location.uri)
			local wins = vim.fn.win_findbuf(buf)
			local start_col, end_col = range_to_cols(client, buf, range)

			-- verify uri is currently visibile and skip multi line ranges
			local same_as_cursor = line == state.cword.line and start_col == state.cword.start_col and end_col == state.cword.end_col
			if #wins > 0 and line == range["end"].line and not same_as_cursor then
				if line == state.cword.line and state.cword.start_col > start_col then
					win_offset = win_offset + range["end"].character - range.start.character
				end

				local extmark_id = vim.api.nvim_buf_set_extmark(buf, EXTMARK_NS, line, start_col, {
					end_col = end_col,
					virt_text_pos = "inline",
					virt_text = { { state.new_text, config.highlights.others } },
					conceal = ""
				})

				table.insert(state.references, {
					buf = buf,
					line = line,
					start_col = start_col,
					end_col = end_col,
					extmark_id = extmark_id
				})
			end
		end

		if win_offset > 0 then
			vim.api.nvim_win_set_config(state.input_win, {
				relative = "win",
				win = state.current_win,
				bufpos = { state.cword.line, state.cword.start_col },
				row = 0,
				col = -win_offset
			})
		end

		input_update() -- update now that we received references
	end)
end

local function lsp_request_sync(client, method, params, bufnr)
	local request_result = nil
    local function sync_handler(err, result, context, config)
        request_result = {
            err = err,
            result = result,
            context = context,
            config = config
        }
    end

    local success, request_id = client:request(method, params, sync_handler, bufnr)
    if not success then
        return nil
    end

    local wait_result = vim.wait(config.request_timeout, function()
        return request_result ~= nil
    end, 5)

    if not wait_result then
        if request_id then
            client:cancel_request(request_id)
        end
        return nil
    end

    return request_result
end

function M.setup(user_config)
	config = vim.tbl_deep_extend("force", config, user_config or {})
end

function M.hide()
	vim.wo[state.current_win].conceallevel = state.prev_conceal
	vim.api.nvim_buf_clear_namespace(state.current_buf, EXTMARK_NS, 0, -1)

	if vim.api.nvim_win_is_valid(state.input_win) then
		vim.api.nvim_win_close(state.input_win, false)
	end

	if vim.api.nvim_buf_is_valid(state.input_buf) then
		vim.api.nvim_buf_delete(state.input_buf, {})
	end

	vim.cmd.stopinsert()
end

function M.submit()
	-- TODO: show rename menu
	local menu = require("rename.menu")
	menu.open_rename_menu({}, state.new_text)
end

function M.live_rename()
	local current_buf = vim.api.nvim_get_current_buf()
	local current_win = vim.api.nvim_get_current_win()

	local clients = vim.lsp.get_clients({
		bufnr = current_buf,
		method = RENAME_METHOD
	})

	local client = clients[1]
	if not client then
		vim.notify("[live-rename] no server found")
		return
	end

	local position_params = vim.lsp.util.make_position_params(current_win, client.offset_encoding)
	local initial_pos = vim.api.nvim_win_get_cursor(current_win)
	local cword = nil

	-- prepare rename
	if client:supports_method(PREP_RENAME_METHOD) then
		local resp = lsp_request_sync(client, PREP_RENAME_METHOD, position_params, current_buf)
		if not resp or resp.err ~= nil or resp.result == nil then
			if resp and resp.err then
				notify_error("[lsp-rename] error preparing rename", resp and resp.err)
			else
				notify_error("[lsp-rename] invalid position")
			end

			return
		end

		local result = resp.result
		if result.defaultBehavior then
			-- fallback
		elseif result.range then
			local start_col, end_col = range_to_cols(client, current_buf, result.range)
            cword = {
                line = result.range.start.line,
                start_col = start_col,
                end_col = end_col,
                text = tostring(result.placeholder),
                initial_offset = initial_pos[2] - start_col,
            }
		else
			local range = result
            local line = range.start.line
            local lines = vim.api.nvim_buf_get_lines(current_buf, line, line + 1, true)
            local start_col, end_col = range_to_cols(client, current_buf, range)

            cword = {
                line = line,
                start_col = start_col,
                end_col = end_col,
                text = string.sub(lines[1], start_col + 1, end_col),
                initial_offset = initial_pos[2] - start_col,
            }
		end
	end

	-- use <cword> as a fallback
    if not cword then
        -- search backward for next word
        vim.fn.search("\\w\\+", "bcW")
        local new_pos = vim.api.nvim_win_get_cursor(current_win)
        local text = vim.fn.expand("<cword>")

        -- restore cursor position
        vim.api.nvim_win_set_cursor(0, initial_pos)

        local on_same_line = new_pos[1] == initial_pos[1]
        -- we only need to check the end bound since we're searching backwards
        local in_char_range = new_pos[2] + #text >= initial_pos[2]
        if text == "" or not on_same_line or not in_char_range then
            notify_error("[LSP] rename, no word found")
            return
        end

        cword = {
            line = new_pos[1] - 1,
            start_col = new_pos[2],
            end_col = new_pos[2] + #text,
            text = text,
            initial_offset = initial_pos[2] - new_pos[2],
        }
    end

	state.cword = cword
	state.current_win = current_win
	state.current_buf = current_buf

	-- fetch references to preview other affected lines
	local text = cword.text
	local text_width = vim.fn.strdisplaywidth(text)

	state.new_text = text
	state.references = {}
	state.transaction_id = state.transaction_id + 1
	fetch_references(client, current_buf, position_params, state.transaction_id)

	local input_buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(input_buf, "lsp:rename")
	vim.api.nvim_buf_set_lines(input_buf, 0, 1, false, { text })

	local input_win = vim.api.nvim_open_win(input_buf, false, {
		relative = "win",
		win = current_win,
		bufpos = { cword.line, cword.start_col },
		row = 0,
		col = 0,
		width = text_width + 2,
		height = 1,
		style = "minimal",
		border = "none"
	})

	-- conceal word in document
	state.prev_conceal = vim.wo[current_win].conceallevel
	vim.wo[current_win].conceallevel = 2

	state.extmark_id = vim.api.nvim_buf_set_extmark(current_buf, EXTMARK_NS, cword.line, cword.start_col, {
		end_col = cword.end_col,
		virt_text_pos = "inline",
		virt_text = { { string.rep(" ", text_width), config.highlights.current } },
		conceal = ""
	})

	-- window options
	vim.wo[input_win].wrap = true
	vim.api.nvim_set_option_value("winblend", 100, {
		scope = "local",
		win = input_win
	})

	vim.api.nvim_set_hl(WIN_HL_NS, "Normal", { fg = nil, bg = nil })
	vim.api.nvim_win_set_hl_ns(input_win, WIN_HL_NS)

	state.input_win = input_win
	state.input_buf = input_buf

	-- setup mappings
	for _, key in ipairs(config.mappings.submit) do
		vim.keymap.set(key[1], key[2], M.submit, {
			buffer = input_buf,
			desc = "Submit rename"
		})
	end

	for _, key in ipairs(config.mappings.cancel) do
		vim.keymap.set(key[1], key[2], M.hide, {
			buffer = input_buf,
			desc = "Cancel rename"
		})
	end

	-- register listeners
	local group = vim.api.nvim_create_augroup("live-rename", {})
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "TextChangedP", "CursorMoved" }, {
		group = group,
		buffer = input_buf,
		callback = input_update
	})

	vim.api.nvim_create_autocmd("WinLeave", {
		group = group,
		buffer = input_buf,
		once = true,
		callback = M.hide
	})

	vim.api.nvim_set_current_win(input_win)
	vim.cmd.startinsert()
	vim.api.nvim_win_set_cursor(input_win, {1, text_width + 1 })
end

return M

