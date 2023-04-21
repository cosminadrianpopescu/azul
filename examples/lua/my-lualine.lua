local mx = require('azul')
vim.api.nvim_create_autocmd('User', {
    pattern = "", callback = function(ev)
        if ev.match ~= 'MxModeChanged' then
            return
        end
        require('lualine').refresh()
    end
})

local colors = require('tokyonight.colors').default

vim.api.nvim_command('highlight CurrentTab guibg=' .. colors.yellow)

local MOD_MAP = {
    t = {
        text = '  TERMINAL ',
        color = colors.green,
    },
    c = {
        text = '  COMMAND  ',
        color = colors.yellow,
    },
    n = {
        text = '   NORMAL  ',
        color = colors.blue,
    },
    v = {
        text = '  VISUAL  ',
        color = colors.magenta,
    },
    p = {
        text = 'PANE SELECT',
        color = colors.red,
    },
    m = {
        text = ' FLOAT MOVE',
        color = colors.red,
    },
    r = {
        text = 'PANE RESIZE',
        color = colors.red,
    },
    s = {
        text = '   SPLIT   ',
        color = colors.red,
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

require('lualine').setup {
    options = {
        icons_enabled = true,
        theme = 'auto',
        component_separators = { left = '', right = ''},
        section_separators = { left = '', right = ''},
        disabled_filetypes = {
            statusline = {},
            winbar = {},
        },
        color = function(section)
            if section.section == 'a' then
                return {bg = last_color, fg = colors.bg_dark}
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
            },
            {
                current_tab,
                color = function()
                    return {bg = colors.yellow, fg = colors.bg_dark}
                end,
                separator = { right = '', left = ''},
            },
            {
                next_tabs,
                separator = { right = '', left = ''},
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

