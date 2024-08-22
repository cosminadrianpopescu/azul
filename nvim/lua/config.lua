local M = {}

local files = require('files')
local split = require('split')
local cmd = vim.api.nvim_create_autocmd
local tabs = 0

local float_group = function()
    return vim.t.float_group or 'default' -- we can set on a tab the t:float_group variable and
                                          -- then all the floats on that tab
                                          -- will be assigned to the t:float_group group
end

local feedkeys = function(keys)
    local codes = vim.api.nvim_replace_termcodes('<C-\\><c-n>' .. keys, true, false, true)
    vim.api.nvim_feedkeys(codes, 't', false)
end

cmd('TermClose', {
    pattern = "*", callback = function()
        local azul = require('azul')
        if azul.get_current_workflow() ~= 'zellij' and azul.get_current_workflow() ~= 'tmux' then
            return
        end
        vim.fn.timer_start(1, function()
            vim.fn.feedkeys('i')
        end)
    end
})

local actions = {
    'select_terminal',
    'select_session',
    'create_tab',
    'tab_select',
    'toggle_floats',
    'enter_mode',
    'create_float',
    'disconnect',
    'nested',
    'resize_left', 'resize_right', 'resize_up', 'resize_down',
    'select_left', 'select_right', 'select_up', 'select_down',
    'move_left', 'move_right', 'move_up', 'move_down',
    'move_top', 'move_bottom', 'move_start', 'move_end',
    'split_left', 'split_right', 'split_up', 'split_down',
    'tab_select_first', 'tab_select_last', 'tab_select_next', 'tab_select_previous'
}

local modes = {
    terminal = 't', azul = 'n', resize = 'r', pane = 'p', move = 'm', split = 's', tabs = 'T'
}

M.default_config = {
    options = {
        workflow = 'azul',
        modifier = '<C-s>',
        link_floats_with_tabs = false,
        shell = nil,
        mouse = "",
        cmdheight = 0,
        theme = 'dracula',
        termguicolors = true,
        scrollback = 2000,
    },
    shortcuts = {
        azul = {
            terminal = {
                select_terminal = 'St',
                select_session = 'Ss',
                create_tab = 'c',
                tab_select = {
                    ["1"] = '1',
                    ["2"] = '2',
                    ["3"] = '3',
                    ["4"] = '4',
                    ["5"] = '5',
                    ["6"] = '6',
                    ["7"] = '7',
                    ["8"] = '8',
                    ["9"] = '9',
                },
                toggle_floats = 'w',
                enter_mode = {
                    p = 'p',
                    r = 'r',
                    m = 'm',
                    s = 's',
                    T = 'T',
                    n = 'n',
                },
                create_float = 'f',
                disconnect = 'd',
                nested = 'N',
            },
            resize = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                resize_left = 'h', resize_right = 'l', resize_up = 'k', resize_down = 'j',
            },
            pane = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                select_left = 'h', select_right = 'l', select_up = 'k', select_down = 'j',
                split_left = 'H', split_right = 'L', split_up = 'K', split_down = 'J',
            },
            move = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                move_left = {
                    ["5"] = 'h',
                    ["1"] = '<C-h>',
                },
                move_right = {
                    ['5'] = 'l',
                    ['1'] = '<c-l>',
                },
                move_up ={
                    ['5'] = 'k',
                    ['1'] = '<C-k>',
                },
                move_down = {
                    ['5'] = 'j',
                    ['1'] = '<C-j>',
                },
                move_top = 'K', move_bottom = 'J', move_start = 'H', move_end = 'L',
            },
            split = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                split_left = 'h', split_right = 'l', split_up = 'k', split_down = 'j',
            },
            tabs = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                tab_select_first = 'H', tab_select_last = 'L', tab_select_previous = 'h', tab_select_next = 'l', create_tab = 'c',
            },
        },
        tmux = {
            azul = {
                create_tab = 'c',
                tab_select = {
                    ["1"] = '1',
                    ["2"] = '2',
                    ["3"] = '3',
                    ["4"] = '4',
                    ["5"] = '5',
                    ["6"] = '6',
                    ["7"] = '7',
                    ["8"] = '8',
                    ["9"] = '9',
                },
                toggle_floats = 'w',
                enter_mode = {
                    p = 'p',
                    r = 'r',
                    m = 'm',
                    s = 's',
                    T = 'T',
                },
                create_float = 'f',
                disconnect = 'd',
                nested = 'N',
            },
            resize = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                resize_left = 'h', resize_right = 'l', resize_up = 'k', resize_down = 'j',
            },
            pane = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                select_left = 'h', select_right = 'l', select_up = 'k', select_down = 'j',
                split_left = 'H', split_right = 'L', split_up = 'K', split_down = 'J',
            },
            move = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                move_left = {
                    ['5'] = 'h',
                    ['1'] = '<C-h>',
                },
                move_right = {
                    ['5'] = 'l',
                    ['1'] = '<c-l>',
                },
                move_up ={
                    ['5'] = 'k',
                    ['1'] = '<C-k>',
                },
                move_down = {
                    ['5'] = 'j',
                    ['1'] = '<C-j>',
                },
                move_top = 'K', move_bottom = 'J', move_start = 'H', move_end = 'L',
            },
            split = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                split_left = 'h', split_right = 'l', split_up = 'k', split_down = 'j',
            },
            tabs = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                tab_select_first = 'H', tab_select_last = 'L', tab_select_previous = 'h', tab_select_next = 'l', create_tab = 'c',
            },
        },
        zellij = {
            terminal = {
                enter_mode = {
                    p = '<C-p>',
                    r = '<C-r>',
                    m = '<C-v>',
                    s = '<C-s>',
                    T = '<C-S-t>',
                    n = '<C-a>',
                },
                disconnect = '<C-d>',
                nested = '<A-n>',
            },
            resize = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                resize_left = 'h', resize_right = 'l', resize_up = 'k', resize_down = 'j',
            },
            pane = {
                create_tab = 'c',
                enter_mode = {t = '<esc>'},
                toggle_floats = 'w',
                create_float = 'f',
                select_left = 'h', select_right = 'l', select_up = 'k', select_down = 'j',
                split_left = 'H', split_right = 'L', split_up = 'K', split_down = 'J',
            },
            move = {
                enter_mode = {t = '<esc>'},
                move_left = {
                    ['5'] = 'h',
                    ['1'] = '<C-h>',
                },
                move_right = {
                    ['5'] = 'l',
                    ['1'] = '<c-l>',
                },
                move_up ={
                    ['5'] = 'k',
                    ['1'] = '<C-k>',
                },
                move_down = {
                    ['5'] = 'j',
                    ['1'] = '<C-j>',
                },
                move_top = 'K', move_bottom = 'J', move_start = 'H', move_end = 'L',
            },
            split = {
                enter_mode = {t = '<esc>'},
                split_left = 'h', split_right = 'l', split_up = 'k', split_down = 'j',
            },
            tabs = {
                enter_mode = {t = '<esc>'},
                tab_select_first = 'H', tab_select_last = 'L', tab_select_previous = 'h', tab_select_next = 'l', create_tab = 'c',
            },
        },
        emacs = {
            terminal = {
                create_tab = '<A-c>',
                tab_select = {
                    ["1"] = '<A-1>',
                    ["2"] = '<A-2>',
                    ["3"] = '<A-3>',
                    ["4"] = '<A-4>',
                    ["5"] = '<A-5>',
                    ["6"] = '<A-6>',
                    ["7"] = '<A-7>',
                    ["8"] = '<A-8>',
                    ["9"] = '<A-9>',
                },
                toggle_floats = '<a-w>',
                disconnect = '<a-d>',
                create_float = '<a-f>',
                select_left = '<a-h>',
                select_right = '<a-l>',
                select_up = '<a-k>',
                select_down = '<a-j>',
                split_left = '<c-h>',
                split_right = '<c-l>',
                split_up = '<c-k>',
                split_down = '<c-j>',
                move_left = {
                    ["5"] = '<c-a-h>',
                },
                move_right = {
                    ["5"] = '<c-a-l>',
                },
                move_up = {
                    ["5"] = '<c-a-k>',
                },
                move_down = {
                    ["5"] = '<c-a-j>',
                },
                move_top = '<c-a-n>',
                move_bottom = '<c-a-s>',
                move_start = '<c-a-w>',
                move_end = '<c-a-e>',
                resize_left = '<c-left>',
                resize_right = '<c-right>',
                resize_up = '<c-up>',
                resize_down = '<c-down>',
                nested = '<a-n>',
                tab_select_first = '<c-x>H',
                tab_select_last = '<c-x>L',
                tab_select_previous = '<c-x>h',
                tab_select_next = '<c-x>l',
            },
        }
    }
}

local set_shortcut = function(action, shortcut, mode, arg)
    local azul = require('azul')
    local map = azul.set_key_map
    local wf = azul.get_current_workflow()

    local t = function(key, callback, what)
        map(mode, key, '', {
            callback = function()
                local opts = require('telescope.themes').get_ivy({})
                callback(opts)
            end,
            desc = "Select a " .. what,
        })
    end

    local start_insert = function()
        vim.fn.timer_start(1, function()
            vim.api.nvim_command('startinsert')
        end)
    end

    local wrap_for_insert = function(callback)
        callback()
        if wf ~= 'zellij' and wf ~= 'tmux' then
            return
        end
        start_insert()
    end

    if action == 'select_terminal' or action == 'select_session' then
        local callback = (action == 'select_terminal' and require('sessions').term_select) or require('sessions').sessions_list
        t(shortcut, callback, action:gsub('select_', ''))
    elseif action == 'create_tab' then
        map(mode, shortcut, '', {
            callback = function()
                if mode ~= 't' then
                    azul.enter_mode('t')
                end
                azul.open()
                if M.default_config.options.link_floats_with_tabs then
                    vim.fn.timer_start(1, function()
                        azul.set_tab_variable('float_group', 'tab-' .. tabs)
                        tabs = tabs + 1
                    end)
                end
            end,
            desc = 'Creates a new tab',
        })
    elseif action == 'tab_select' then
        map(mode, shortcut, '', {
            callback = function()
                wrap_for_insert(function()
                    local hidden = azul.are_floats_hidden(float_group())
                    if not hidden then
                        azul.hide_floats()
                    end
                    vim.api.nvim_command('tabn ' .. arg)
                    if not hidden then
                        azul.show_floats(float_group())
                    end
                end)
            end,
            desc = 'Go to tab ' .. arg
        })
    elseif action == 'toggle_floats' then
        map(mode, shortcut, '', {
            callback = function()
                wrap_for_insert(function()
                    azul.toggle_floats(float_group())
                end)
            end,
            desc = "Toggle floats visibility",
        })
    elseif action == 'enter_mode' then
        if arg == 'n' then
            map(mode, shortcut, '<C-\\><C-n>', {
                desc = 'Enter azul mode',
            })
            return
        end
        local mapping = {
            p = 'pane',
            r = 'resize',
            m = 'move',
            s = 'split',
            T = 'tabs',
            t = 'terminal',
            n = 'azul',
        }
        map(mode, shortcut, '', {
            callback = function()
                azul.enter_mode(arg)
                if arg == 't' and (wf == 'tmux' or wf == 'zellij') then
                    start_insert()
                end
            end,
            desc = "Enter " .. mapping[arg] .. " mode"
        })
    elseif action == 'create_float' then
        map(mode, shortcut, '', {
            callback = function()
                wrap_for_insert(function()
                    azul.open_float(float_group())
                end)
            end,
            desc = "Create float"
        })
    elseif action == 'disconnect' then
        map(mode, shortcut, '', {
            callback = azul.disconnect,
            desc = "Disconnect",
        })
    elseif action == 'nested' then
        map(mode, shortcut, '', {
            callback = azul.toggle_nested_mode,
            desc = 'Toggle nested session'
        })
    elseif action == 'resize_left' or action == 'resize_right' or action == 'resize_down' or action == 'resize_up' then
        local args = {
            resize_left = 'vert res -5',
            resize_right = 'vert res +5',
            resize_up = 'res -5',
            resize_down = 'res +5',
        }
        map(mode, shortcut, '', {
            callback = function()
                if wf ~= 'emacs' then
                    vim.api.nvim_command(args[action])
                else
                    feedkeys(':' .. args[action] .. '<cr>i')
                end
            end,
        })
    elseif action == 'select_left' or action == 'select_right' or action == 'select_down' or action == 'select_up' then
        local dir = action:gsub('select_', '')
        map(mode, shortcut, '', {
            callback = function()
                azul.select_next_term(dir, float_group())
            end,
            desc = 'Select a pane to the ' .. dir
        })
    elseif action == 'move_left' or action == 'move_right' or action == 'move_up' or action == 'move_down' then
        local dir = action:gsub('move_', '')
        map(mode, shortcut, '', {
            callback = function()
                azul.move_current_float(dir, arg)
            end,
            desc = 'Move a panel to ' .. dir
        })
    elseif action == 'split_left' or action == 'split_right' or action == 'split_up' or action == 'split_down' then
        local dir = action:gsub('split_', '')
        map(mode, shortcut, '', {
            callback = function()
                azul.split(dir)
            end,
            desc = 'Split to ' .. dir
        })
    elseif action == 'move_top' or action == 'move_bottom' or action == 'move_start' or action == 'move_end' then
        local dir = action:gsub('move_', '')
        map(mode, shortcut, '', {
            callback = function()
                azul.position_current_float(dir)
            end,
            desc = 'Move current pane to ' .. dir
        })
    elseif action == 'tab_select_first' or action == 'tab_select_last' or action == 'tab_select_previous' or action == 'tab_select_next' then
        local args = {
            tab_select_first = 'tabfirst', tab_select_next = 'tabnext', tab_select_previous = 'tabprev', tab_select_last = 'tablast',
        }
        map(mode, shortcut, '', {
            callback = function()
                vim.api.nvim_command(args[action])
            end
        })
    end
end

M.load_config = function(where)
    local t = files.read_ini(where)
    if t.options ~= nil then
        for key, value in pairs(t.options) do
            if value == 'true' then
                value = true
            elseif value == 'false' then
                value = false
            elseif tonumber(value) ~= nil then
                value = tonumber(value)
            end
            M.default_config.options[key] = value
        end
    end

    local wf = M.default_config.options.workflow

    if t.shortcuts ~= nil then
        local collection = t.shortcuts
        if wf == 'emacs' then
            collection = {terminal = t.shortcuts}
        end
        for mode, shortcuts in pairs(collection) do
            for action, keys in pairs(shortcuts) do
                if M.default_config.shortcuts[wf][mode] == nil and modes[mode] ~= nil then
                    M.default_config.shortcuts[wf][mode] = {}
                end
                if type(keys) ~= 'table' or (vim.tbl_contains(actions, action) and M.default_config.shortcuts[wf][mode][action] == nil) then
                    M.default_config.shortcuts[wf][mode][action] = keys
                else
                    for arg, real_keys in pairs(keys) do
                        M.default_config.shortcuts[wf][mode][action][arg] = real_keys
                    end
                end
            end
        end
    end
end

local set_wk = function(wf)
    local wk = require('which-key')
    if wf ~= 'azul' then
        wk.setup({
            triggers = {},
        })

        return
    end
    wk.setup({
        -- triggers = {'<c-s>'}
        triggers_no_wait = {
            M.default_config.options.modifier,
        },
        win = {
            height = { min = 8, max = 25 },
            no_overlap = false,
        }
    })

    wk.register({
        [M.default_config.options.modifier] = {
            ['<cr>'] = {'', 'Cancel'},
            i = {'', 'Cancel'},
        }
    }, {
            mode = "t",
        })
end

M.apply_config = function(_config)
    local config = _config or M.default_config
    local wf = config.options.workflow
    set_wk(wf)
    local do_setshortcut = function(shortcuts, mode)
        for action, keys in pairs(shortcuts) do
            if type(keys) ~= 'table' then
                for _, key in pairs(split.split(keys, '%$%$%$')) do
                    set_shortcut(action, key, mode, nil)
                end
            else
                for arg, key in pairs(keys) do
                    for _, _key in pairs(split.split(key, '%$%$%$')) do
                        set_shortcut(action, _key, mode, arg)
                    end
                end
            end
        end
    end

    for mode, collection in pairs(config.shortcuts[wf]) do
        do_setshortcut(collection, modes[mode])
    end
end

return M
