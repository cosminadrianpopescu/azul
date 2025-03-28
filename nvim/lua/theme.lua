local mx = require('azul')
local options = require('options')

local dressing_opts = {
    input = {enabled = false},
    select = {enabled = false},
}
if options.use_dressing then
    local opts = {
        enabled = true,
        title_pos = 'center',
        start_mode = 'insert',
        relative = 'editor',
        border = "double",
    }
    dressing_opts.input = opts
    dressing_opts.select = opts
end
require('dressing').setup(dressing_opts)

if not options.use_lualine then
    return
end

local is_modifier = false
local theme = options.theme
local disabled = require('disabled-theme')
local is_disabled = false
local wf = mx.get_current_workflow()

local M = {}

local colors = require('lualine.themes.' .. theme)
if colors.terminal == nil then
    colors.terminal = colors.visual
end
if colors.command == nil then
    colors.command = colors.inactive
end

vim.api.nvim_command('highlight link AzulCurrentFloat WinFloat')
vim.api.nvim_command('highlight link AzulInactiveWin Folded')
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
        text = '    AZUL   ',
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
    P = {
        text = 'PASSTHROUGH',
        color = colors.inactive.a.bg,
    },
}

local last_color = nil

local function my_mode()
    local m = mx.current_mode()
    if m == 'i' then
        m = 't'
    end
    last_color = (MOD_MAP[m] and MOD_MAP[m].color) or nil
    return (MOD_MAP[m] and MOD_MAP[m].text) or m
end

local function tabs(from, to)
    local result = ''
    for i, t in ipairs(vim.api.nvim_list_tabpages()) do
        if i >= from and i <= to then
            result = result .. vim.api.nvim_tabpage_get_var(t, 'azul_tab_title')

            if i ~= to then
                result = result .. '  '
            end
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
    local id = vim.api.nvim_list_tabpages()[vim.fn.tabpagenr()]
    return vim.api.nvim_tabpage_get_var(id, 'azul_tab_title')
end

local function current_name()
    return vim.b.term_title or ''
end

local function modifier()
    if wf ~= 'tmux' and wf ~= 'azul' then
        return ''
    end
    return (is_modifier and mx.get_current_modifier()) or ''
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
    local m = mx.current_mode()
    if m == 'P' then
        return {bg = disabled.inactive.a.fg, fg = disabled.inactive.a.bg}
    end
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
        lualine_x = {{
            modifier,
            separator = { right = '', left = ''},
            color = {bg = colors.terminal.a.bg, fg = colors.terminal.a.fg},
        }, 'encoding', 'fileformat', 'filetype'},
        lualine_y = {'progress'},
        lualine_z = {'location'}
    },
    tabline = {},
    winbar = {},
    inactive_winbar = {},
    extensions = {}
}

mx.persistent_on({'ModifierTrigger'}, function()
    is_modifier = true
    require('lualine').refresh()
end)

mx.persistent_on({'ModifierFinished'}, function()
    is_modifier = false
    require('lualine').refresh()
end)

mx.persistent_on({'ModeChanged', 'TabTitleChanged'}, function()
    if is_disabled and mx.current_mode() ~= 'P' then
        require('lualine').setup({options = {theme = theme}})
        is_disabled = false
    end

    if mx.current_mode() == 'P' then
        is_disabled = true
        require('lualine').setup({options = {theme = disabled}})
    end

    require('lualine').refresh()
end)

mx.persistent_on({'PaneChanged'}, function(args)
    local crt = args[1]
    local what = (mx.is_float(crt) and 'FloatBorder') or 'WinSeparator'
    local repl = (mx.is_float(crt) and 'AzulCurrentFloat') or 'AzulInactiveWin'
    vim.api.nvim_set_option_value('winhl', what .. ':' .. repl, {win = crt.win_id, scope = 'local'})
    for _, t in ipairs(mx.get_terminals()) do
        if t.win_id ~= crt.win_id and t.win_id ~= nil then
            vim.api.nvim_set_option_value('winhl', 'Normal:AzulInactiveWin,FloatBorder:AzulInactiveWin,CursorLine:AzulInactiveWin,CursorColumn:AzulInactiveWin,FloatTitle:AzulInactiveWin', {win = t.win_id, scope = 'local'})
        end
    end
end)

return M
