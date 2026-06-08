vim.opt.cursorline = true
vim.opt.laststatus = 3
vim.opt.background = "dark"
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldtext = ""
vim.opt.foldlevel = 99
vim.opt.fillchars = {
    vert = "▕", -- alternatives │
    fold = " ",
    eob = " ", -- suppress ~ at EndOfBuffer
    diff = "╱", -- alternatives = ⣿ ░ ─
    msgsep = "‾",
    foldopen = "▾",
    foldsep = "│",
    foldclose = "▸",
}

vim.opt.list = true
vim.opt.listchars = {
    tab = "  ",
    multispace = "·",
    space = "·"
}

vim.api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    callback = function()
        vim.api.nvim_set_hl(0, "Whitespace", { fg = "#2b2b29" })

        local bg_color = "#0a0a0a"
        local bg_groups = {
            "Normal",
            "CursorLine",
            "SignColumn",
            "LineNr",
            "CursorLineNr",
            -- "FoldColumn",
            -- "Folded",
            "GitSignsAdd",
            "GitSignsChange",
            "GitSignsDelete",
            "TabLineFill",
            "DiagnosticSignError",
            "DiagnosticSignWarn",
            "DiagnosticSignInfo",
            "DiagnosticSignHint"
        }

        vim.api.nvim_set_hl(0, "WinSeparator", { bg = "background", fg = "#363636" })

        for _, group in ipairs(bg_groups) do
            local existing = vim.api.nvim_get_hl(0, { name = group })
            if existing then
                existing.bg = bg_color
                vim.api.nvim_set_hl(0, group, existing)
            end
        end
    end,
})

vim.opt.sessionoptions = {
    "buffers",
    "curdir",
    "folds",
    "help",
    "tabpages",
    "winsize",
    "globals",
}

require("config.lazy")
require("config.keymaps")
require("config.terminal")

vim.api.nvim_set_hl(0, 'Visual', { bg = '#eb9665', fg = '#693225' })
vim.cmd.colorscheme("kanagawa-dragon")
-- vim.cmd.colorscheme("gruvbox")

vim.api.nvim_create_user_command("DiffOrig", function()
    vim.cmd("vert new")
    vim.cmd("set bt=nofile")
    vim.cmd("r ++edit #")
    vim.cmd("0d_")
    vim.cmd("diffthis")
    vim.cmd("wincmd p")
    vim.cmd("diffthis")
end, {})

vim.api.nvim_create_user_command("LspFormatFolder", function(opts)
    local dir = opts.args ~= "" and opts.args or vim.fn.getcwd()

    local files = vim.fn.systemlist(
        'rg --files ' .. vim.fn.shellescape(dir)
    )

    for _, file in ipairs(files) do
        vim.cmd("edit " .. vim.fn.fnameescape(file))
        vim.lsp.buf.format({ async = false })
        vim.cmd("write")
        vim.cmd("bdelete")
    end
end, { nargs = "?" })

vim.fn.serverstart([[\\.\pipe\nvim-server]])
