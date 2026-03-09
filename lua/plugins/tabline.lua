local cwd = function()
    return "  " .. vim.fn.fnamemodify(vim.fn.getcwd(), ":t") .. " "
end

local function get_highlight(name)
    local hl = vim.api.nvim_get_hl(0, {
		name = name,
		link = true
	})

    if hl.link then
      return get_highlight(hl.link)
    end

    return hl
end

local function get_terminal_pallet()
    local color_map = {
		black = 0,
		red = 1,
		green = 2,
		yellow = 3,
		blue = 4,
		magenta = 5,
		cyan = 6,
		white = 7
    }

    local pallet = {}
    for name, value in pairs(color_map) do
		local global_name = "terminal_color_" .. value
		pallet[name] = vim.g[global_name]
    end

    pallet.fill = get_highlight("TabLineFill")
    pallet.tab = get_highlight("TabLine")
    pallet.sl = get_highlight("StatusLine")
    pallet.sel = get_highlight("TabLineSel")

    return pallet
end

local function make_theme()
    local pallet = get_terminal_pallet()

    return {
		fill = "TabLineFill",
		head = { fg = pallet.fill.bg, bg = pallet.cyan },
		current_tab = { fg = pallet.sel.fg, bg = pallet.sel.bg, bold = true },
		tab = "TabLine"
    }
end

return {
    "nanozuki/tabby.nvim",
    config = function()
		vim.o.showtabline = 2

		vim.keymap.set("n", "<Tab>", ":bnext<CR>")
		vim.keymap.set("n", "<S-Tab>", ":bprevious<CR>")
		vim.keymap.set("n", "<leader>bd", function()
			local current = vim.api.nvim_get_current_buf()
			if #vim.fn.getbufinfo({ buflisted = 1 }) > 1 then
				vim.cmd("bnext")
			end

			vim.cmd("bdelete " .. current)
		end)

		require("tabby").setup({
			line = function(line)
				local theme = make_theme()
				return {
					{
						{ cwd(), hl = theme.head },
						line.sep("", theme.head, theme.fill)
					},
					line.tabs().foreach(function(tab)
						local hl = tab.is_current() and theme.current_tab or theme.tab
						return {
							line.sep("", hl, theme.fill),
							tab.is_current() and "" or "",
							tab.number(),
							line.sep("", hl, theme.fill),

							hl = hl,
							margin = " "
						}
					end),
					line.spacer(),
					line.bufs().foreach(function(buf)
						local hl = buf.is_current() and theme.current_tab or theme.tab

						return {
							line.sep("", hl, theme.fill),
							buf.is_current() and "" or "",
							buf.name(),
							buf.is_changed() and "" or "",
							line.sep("", hl, theme.fill),

							hl = hl,
							margin = " "
						}
					end)
				}
			end
		})
    end
}

