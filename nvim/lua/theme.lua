local mx = require('azul')
local theme = 'everforest'

local colors = require('lualine.themes.' .. theme)
if colors.terminal == nil then
    colors.terminal = colors.visual
end
if colors.command == nil then
    colors.command = colors.inactive
end

vim.api.nvim_command('highlight CurrentFloatSel guifg=' .. colors.replace.a.bg)
vim.api.nvim_set_hl(0, 'NormalFloat', {})

local MOD_MAP = {
    t = {
        text = '  TERMINAL ',
        color = colors.terminal.a.bg,
    },
    c = {
        text = '  COMMAND  ',
        color = colors.command.a.fg,
    },
    n = {
        text = '   NORMAL  ',
        color = colors.normal.a.fg,
    },
    v = {
        text = '   VISUAL  ',
        color = colors.visual.a.fg,
    },
    p = {
        text = 'PANE SELECT',
        color = colors.insert.a.bg,
    },
    m = {
        text = ' FLOAT MOVE',
        color = colors.insert.a.bg,
    },
    r = {
        text = 'PANE RESIZE',
        color = colors.insert.a.bg,
    },
    s = {
        text = '   SPLIT   ',
        color = colors.insert.a.bg,
    },
    T = {
        text = '    TABS   ',
        color = colors.insert.a.bg,
    },
}

local last_color = nil

local function my_mode()
    local m = mx.current_mode()
    last_color = (MOD_MAP[m] and MOD_MAP[m].color) or nil
    return (MOD_MAP[m] and MOD_MAP[m].text) or m
end

local function tabs(from, to)
    local result = ''
    for t = from, to do
        result = result .. 'Tab ' .. t

        if t ~= to then
            result = result .. '  '
        end

    end

    return result
end

local function prev_tabs()
    local crt = vim.fn.tabpagenr()

    if crt == 1 then
        return ''
    end

    return tabs(1, crt - 1)
end

local function next_tabs()
    local crt = vim.fn.tabpagenr()
    local n = #vim.api.nvim_list_tabpages()

    if crt == n then
        return ''
    end
    return tabs(crt + 1, n)
end

local function current_tab()
    return 'Tab ' .. vim.fn.tabpagenr()
end

local function current_name()
    return vim.b.term_title
end

local line_utils = require('lualine.utils.utils')

local obj = require('lualine.components.filename');
local old_update_status = obj.update_status;
obj.update_status = function(self)
    local result = old_update_status(self)
    if result == nil then
        return ''
    end
    return line_utils.stl_escape(result) or ''
end
local other_colors = function()
    return {bg = colors.normal.a.fg, fg = colors.normal.a.bg}
end

require('lualine').setup {
    options = {
        icons_enabled = true,
        theme = theme,
        component_separators = { left = '', right = ''},
        section_separators = { left = '', right = ''},
        disabled_filetypes = {
            statusline = {},
            winbar = {},
        },
        color = function(section)
            if section.section == 'a' then
                local fg = colors.terminal.a.fg
                if last_color == fg then
                    return {bg = colors.normal.a.bg, fg = fg}
                end
                return {bg = last_color, fg = fg}
            end

            return nil
        end,
        ignore_focus = {},
        always_divide_middle = true,
        globalstatus = true,
        refresh = {
            statusline = 60000,
            tabline = 60000,
            winbar = 60000,
        }
    },
    sections = {
        lualine_a = {{
            my_mode,
            separator = { right = '', left = ''},
            min_length = 30,
        }},
        lualine_b = {
            {
                prev_tabs,
                separator = { right = '', left = ''},
                color = other_colors,
            },
            {
                current_tab,
                separator = { right = '', left = ''},
            },
            {
                next_tabs,
                separator = { right = '', left = ''},
                color = other_colors,
            },
        },
        lualine_c = {
            {current_name}
        },
        lualine_x = {'encoding', 'fileformat', 'filetype'},
        lualine_y = {'progress'},
        lualine_z = {'location'}
    },
    tabline = {},
    winbar = {},
    inactive_winbar = {},
    extensions = {}
}

vim.api.nvim_create_autocmd('User', {
    pattern = "", callback = function(ev)
        if ev.match ~= 'MxModeChanged' then
            return
        end
        require('lualine').refresh()
    end
})
