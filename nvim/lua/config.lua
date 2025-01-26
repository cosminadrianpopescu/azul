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

cmd({'TabNew', 'VimEnter'}, {
    pattern = "*", callback = function()
        local azul = require('azul')
        if not M.default_config.options.link_floats_with_tabs then
            azul.set_tab_variable('float_group', 'default')
            return
        end
        vim.fn.timer_start(1, function()
            azul.set_tab_variable('float_group', 'tab-' .. tabs)
            tabs = tabs + 1
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
    'passthrough',
    'resize_left', 'resize_right', 'resize_up', 'resize_down',
    'select_left', 'select_right', 'select_up', 'select_down',
    'move_left', 'move_right', 'move_up', 'move_down',
    'move_top', 'move_bottom', 'move_start', 'move_end',
    'split_left', 'split_right', 'split_up', 'split_down',
    'tab_select_first', 'tab_select_last', 'tab_select_next', 'tab_select_previous',
    'copy', 'paste', 'rotate_panel',
    'rename_tab', 'edit_scrollback', 'edit_scrollback_log',
    'show_mode_cheatsheet',
}

local modes = {
    terminal = 't', azul = 'n', resize = 'r', pane = 'p', move = 'm', split = 's', tabs = 'T', visual = 'v', passthrough = 'P',
}

M.default_config = {
    options = {
        workflow = 'azul',
        modifier = '<C-s>',
        link_floats_with_tabs = false,
        shell = nil,
        mouse = "a",
        cmdheight = 0,
        theme = 'dracula',
        termguicolors = true,
        scrollback = 2000,
        clipboard = "unnamedplus",
        encoding = "utf-8",
        hide_in_passthrough = false,
        passthrough_escape = '<C-\\><C-s>',
        modifer_timeout = 500,
        use_cheatsheet = true,
        blocking_cheatsheet = true,
        pane_title = ':term_title:',
        tab_title = 'Tab :tab_n:',
        use_dressing = true,
        opacity = 0,
        use_lualine = true,
        auto_start_logging = false,
    },
    shortcuts = {
        azul = {
            terminal = {
                select_terminal = 'St',
                select_session = 'Ss',
                passthrough = 'N',
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
                    v = 'v',
                    P = 'P',
                },
                create_float = 'f',
                disconnect = 'd',
                paste = 'pp$$$<C-v>',
            },
            resize = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                resize_left = 'h$$$<left>', resize_right = 'l$$$<right>', resize_up = 'k$$$<up>', resize_down = 'j$$$<down>',
                show_mode_cheatsheet = '<C-o>',
            },
            pane = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                select_left = 'h$$$<left>', select_right = 'l$$$<right>', select_up = 'k$$$<up>', select_down = 'j$$$<down>',
                split_left = 'H$$$<s-left>', split_right = 'L$$$<s-right>', split_up = 'K$$$<s-up>', split_down = 'J$$$<s-down>',
                rotate_panel = 'x',
                edit_scrollback = 'e', edit_scrollback_log = 'ge',
                show_mode_cheatsheet = '<C-o>',
            },
            move = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                move_left = {
                    ["5"] = 'h$$$<left>',
                    ["1"] = '<C-h>$$$<C-left>',
                },
                move_right = {
                    ['5'] = 'l$$$<right>',
                    ['1'] = '<c-l>$$$<c-right>',
                },
                move_up ={
                    ['5'] = 'k$$$<up>',
                    ['1'] = '<C-k>$$$<C-up>',
                },
                move_down = {
                    ['5'] = 'j$$$<down>',
                    ['1'] = '<C-j>$$$<c-down>',
                },
                move_top = 'K$$$<s-up>', move_bottom = 'J$$$<s-down>', move_start = 'H$$$<s-left>', move_end = 'L$$$<s-right>',
                show_mode_cheatsheet = '<C-o>',
            },
            split = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                split_left = 'h$$$<left>', split_right = 'l$$$<right>', split_up = 'k$$$<up>', split_down = 'j$$$<down>',
                show_mode_cheatsheet = '<C-o>',
            },
            tabs = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                tab_select_first = 'H$$$<s-left>', tab_select_last = 'L$$$<s-right>', tab_select_previous = 'h$$$<left>', tab_select_next = 'l$$$<right>', create_tab = 'c',
                rename_tab = 'r',
                show_mode_cheatsheet = '<C-o>',
            },
            visual = {
                copy = 'y$$$<C-c>',
            },
        },
        tmux = {
            terminal = {
                paste = '<C-v>',
            },
            azul = {
                select_terminal = 'St',
                select_session = 'Ss',
                passthrough = 'N',
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
                    v = 'v',
                    P = 'P',
                },
                create_float = 'f',
                disconnect = 'd',
            },
            resize = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                resize_left = 'h$$$<left>', resize_right = 'l$$$<right>', resize_up = 'k$$$<up>', resize_down = 'j$$$<down>',
                show_mode_cheatsheet = '<C-o>',
            },
            pane = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                select_left = 'h$$$<left>', select_right = 'l$$$<right>', select_up = 'k$$$<up>', select_down = 'j$$$<down>',
                split_left = 'H$$$<s-left>', split_right = 'L$$$<s-right>', split_up = 'K$$$<s-up>', split_down = 'J$$$<s-down>',
                rotate_panel = 'x',
                edit_scrollback = 'e', edit_scrollback_log = 'ge',
                show_mode_cheatsheet = '<C-o>',
            },
            move = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                move_left = {
                    ["5"] = 'h$$$<left>',
                    ["1"] = '<C-h>$$$<C-left>',
                },
                move_right = {
                    ['5'] = 'l$$$<right>',
                    ['1'] = '<c-l>$$$<c-right>',
                },
                move_up ={
                    ['5'] = 'k$$$<up>',
                    ['1'] = '<C-k>$$$<C-up>',
                },
                move_down = {
                    ['5'] = 'j$$$<down>',
                    ['1'] = '<C-j>$$$<c-down>',
                },
                move_top = 'K$$$<s-up>', move_bottom = 'J$$$<s-down>', move_start = 'H$$$<s-left>', move_end = 'L$$$<s-right>',
                show_mode_cheatsheet = '<C-o>',
            },
            split = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                split_left = 'h$$$<left>', split_right = 'l$$$<right>', split_up = 'k$$$<up>', split_down = 'j$$$<down>',
                show_mode_cheatsheet = '<C-o>',
            },
            tabs = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                tab_select_first = 'H$$$<s-left>', tab_select_last = 'L$$$<s-right>', tab_select_previous = 'h$$$<left>', tab_select_next = 'l$$$<right>', create_tab = 'c',
                rename_tab = 'r',
                show_mode_cheatsheet = '<C-o>',
            },
            visual = {
                copy = 'y$$$<C-c>',
            },
        },
        zellij = {
            terminal = {
                paste = '<C-v>',
                enter_mode = {
                    p = '<C-p>',
                    r = '<C-r>',
                    v = '<C-S-v>',
                    s = '<C-s>',
                    T = '<C-S-t>',
                    n = '<C-a>',
                    m = '<C-s-m>',
                    P = '<C-s-p>',
                },
                disconnect = '<C-d>',
            },
            resize = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                resize_left = 'h$$$<left>', resize_right = 'l$$$<right>', resize_up = 'k$$$<up>', resize_down = 'j$$$<down>',
                show_mode_cheatsheet = '<C-o>',
            },
            pane = {
                select_terminal = 'T',
                select_session = 'S',
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                toggle_floats = 'w',
                create_float = 'f',
                select_left = 'h$$$<left>', select_right = 'l$$$<right>', select_up = 'k$$$<up>', select_down = 'j$$$<down>',
                rotate_panel = 'x',
                edit_scrollback = 'e', edit_scrollback_log = 'ge',
                show_mode_cheatsheet = '<C-o>',
            },
            move = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                move_left = {
                    ["5"] = 'h$$$<left>',
                    ["1"] = '<C-h>$$$<C-left>',
                },
                move_right = {
                    ['5'] = 'l$$$<right>',
                    ['1'] = '<c-l>$$$<c-right>',
                },
                move_up ={
                    ['5'] = 'k$$$<up>',
                    ['1'] = '<C-k>$$$<C-up>',
                },
                move_down = {
                    ['5'] = 'j$$$<down>',
                    ['1'] = '<C-j>$$$<c-down>',
                },
                move_top = 'K$$$<s-up>', move_bottom = 'J$$$<s-down>', move_start = 'H$$$<s-left>', move_end = 'L$$$<s-right>',
                show_mode_cheatsheet = '<C-o>',
            },
            split = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                split_left = 'h$$$<left>', split_right = 'l$$$<right>', split_up = 'k$$$<up>', split_down = 'j$$$<down>',
                show_mode_cheatsheet = '<C-o>',
            },
            tabs = {
                enter_mode = {t =  '<cr>$$$<esc>$$$i'},
                tab_select_first = 'H$$$<s-left>', tab_select_last = 'L$$$<s-right>', tab_select_previous = 'h$$$<left>', tab_select_next = 'l$$$<right>', create_tab = 'c',
                rename_tab = 'r',
                show_mode_cheatsheet = '<C-o>',
            },
            visual = {
                copy = 'y$$$<C-c>',
            }
        },
        emacs = {
            terminal = {
                select_terminal = '<C-S-t>',
                select_session = '<C-S-s>',
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
                select_left = '<a-left>',
                select_right = '<a-right>',
                select_up = '<a-up>',
                select_down = '<a-down>',
                split_left = '<c-left>',
                split_right = '<c-right>',
                split_up = '<c-up>',
                split_down = '<c-down>',
                move_left = {
                    ["5"] = '<c-a-left>',
                },
                move_right = {
                    ["5"] = '<c-a-right>',
                },
                move_up = {
                    ["5"] = '<c-a-up>',
                },
                move_down = {
                    ["5"] = '<c-a-down>',
                },
                move_top = '<c-a-n>',
                move_bottom = '<c-a-s>',
                move_start = '<c-a-w>',
                move_end = '<c-a-e>',
                resize_left = '<c-s-left>',
                resize_right = '<c-s-right>',
                resize_up = '<c-s-up>',
                resize_down = '<c-s-down>',
                passthrough = '<a-n>',
                tab_select_first = '<c-x><s-left>',
                tab_select_last = '<c-x><s-right>',
                tab_select_previous = '<c-x><left>',
                tab_select_next = '<c-x><right>',
                copy = '<C-c>',
                paste = '<C-v>',
                rotate_panel = '<C-x>x',
                rename_tab = '<C-x><C-r>',
                edit_scrollback = '<C-x><C-e>',
                edit_scrollback_log = '<C-x>ge',
            },
        }
    }
}

local set_shortcut = function(action, shortcut, mode, arg)
    local azul = require('azul')
    local map = azul.set_key_map
    local map2 = vim.api.nvim_set_keymap
    local wf = azul.get_current_workflow()

    local t = function(key, callback, what)
        map(mode, key, '', {
            callback = function()
                local opts = require('telescope.themes').get_ivy({})
                callback(opts)
            end,
            desc = "Select a " .. what,
            action = action,
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
            end,
            desc = 'Creates a new tab',
            action = action,
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
            desc = 'Go to tab ' .. arg,
            action = action,
        })
    elseif action == 'toggle_floats' then
        map(mode, shortcut, '', {
            callback = function()
                wrap_for_insert(function()
                    azul.toggle_floats(float_group())
                end)
            end,
            desc = "Toggle floats visibility",
            action = action,
        })
    elseif action == 'enter_mode' then
        local mapping = {
            p = 'pane',
            r = 'resize',
            m = 'move',
            s = 'split',
            T = 'tabs',
            t = 'terminal',
            n = 'azul',
            v = 'visual',
            P = 'passthrough',
        }
        if arg == 'n' or arg == 'v' then
            if mode == 'n' and arg == 'v' then
                return
            end
            local suf = (arg == 'v' and 'v') or ''
            map(mode, shortcut, '<C-\\><C-n>' .. suf, {
                desc = 'Enter ' .. mapping[arg] .. ' mode',
            })
            return
        end
        map(mode, shortcut, '', {
            callback = function()
                azul.enter_mode(arg)
                if arg == 't' and (wf == 'tmux' or wf == 'zellij') then
                    start_insert()
                end
            end,
            desc = "Enter " .. mapping[arg] .. " mode",
            action = action,
        })
    elseif action == 'create_float' then
        map(mode, shortcut, '', {
            callback = function()
                wrap_for_insert(function()
                    azul.open_float(float_group())
                end)
            end,
            desc = "Create float",
            action = action,
        })
    elseif action == 'disconnect' then
        map(mode, shortcut, '', {
            callback = azul.disconnect,
            desc = "Disconnect",
            action = action,
        })
    elseif action == 'resize_left' or action == 'resize_right' or action == 'resize_down' or action == 'resize_up' then
        local where = action:gsub('resize_', '')
        map(mode, shortcut, '', {
            callback = function()
                azul.resize(where)
            end,
            desc = "Resize " .. where,
            action = action,
        })
    elseif action == 'select_left' or action == 'select_right' or action == 'select_down' or action == 'select_up' then
        local dir = action:gsub('select_', '')
        map(mode, shortcut, '', {
            callback = function()
                azul.select_next_pane(dir, float_group())
            end,
            desc = 'Select a pane ' .. dir,
            action = action,
        })
    elseif action == 'move_left' or action == 'move_right' or action == 'move_up' or action == 'move_down' then
        local dir = action:gsub('move_', '')
        map(mode, shortcut, '', {
            callback = function()
                azul.move_current_float(dir, arg)
            end,
            desc = 'Move a panel to ' .. dir,
            action = action,
        })
    elseif action == 'split_left' or action == 'split_right' or action == 'split_up' or action == 'split_down' then
        local dir = action:gsub('split_', '')
        map(mode, shortcut, '', {
            callback = function()
                azul.split(dir)
            end,
            desc = 'Split ' .. dir,
            action = action,
        })
    elseif action == 'move_top' or action == 'move_bottom' or action == 'move_start' or action == 'move_end' then
        local dir = action:gsub('move_', '')
        map(mode, shortcut, '', {
            callback = function()
                azul.position_current_float(dir)
            end,
            desc = 'Move current pane to ' .. dir,
            action = action,
        })
    elseif action == 'tab_select_first' or action == 'tab_select_last' or action == 'tab_select_previous' or action == 'tab_select_next' then
        local args = {
            tab_select_first = 'tabfirst', tab_select_next = 'tabnext', tab_select_previous = 'tabprev', tab_select_last = 'tablast',
        }
        local where = action:gsub('tab_select_', '')
        map(mode, shortcut, '', {
            callback = function()
                vim.api.nvim_command(args[action])
            end,
            desc = "Select " .. where .. " tab",
            action = action,
        })
    elseif action == 'copy' then
        if wf ~= 'emacs' and mode ~= 'v' then
            error("You tried to set the copy action shortcut in mode " .. mode .. ". The copy action can only be set for visual mode")
        end
        if shortcut == 'y' then
            return
        end
        map2('v', shortcut, 'yi', {
            desc = 'Copy selected text',
        })
    elseif action == 'paste' then
        local callback = (wf == 'azul' and mode == 't' and shortcut:match('^<.*>$') and map2) or map
        callback(mode, shortcut, '', {
            callback = azul.paste_from_clipboard,
            desc = 'Paste from clipboard',
        })
    elseif action == 'passthrough' then
        map(mode, shortcut, '', {
            callback = function()
                azul.toggle_passthrough()
            end,
            desc = 'Toggle passthrough mode',
            action = action,
        })
    elseif action == 'rotate_panel' then
        map(mode, shortcut, '', {
            callback = function()
                azul.rotate_panel()
            end,
            desc = 'Rotates the current panel',
            action = action,
        })
    elseif action == 'rename_tab' then
        map(mode, shortcut, '', {
            callback = azul.rename_current_tab,
            desc = 'Renames the current tab',
            action = action,
        })
    elseif action == 'edit_scrollback' then
        map(mode, shortcut, '', {
            callback = function()
                azul.edit_current_scrollback()
                azul.enter_mode('t')
            end,
            desc = 'Edits the scrollback buffer',
            action = action,
        })
    elseif action == 'edit_scrollback_log' then
        map(mode, shortcut, '', {
            callback = function()
                azul.edit_current_scrollback_log()
                azul.enter_mode('t')
            end,
            desc = 'Edits the scrollback log',
            action = action,
        })
    elseif action == 'show_mode_cheatsheet' then
        map(mode, shortcut, '', {
            callback = function()
                print("TOGGLE ALL")
            end,
            desc = "All shortcuts",
            action = action,
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
                        if M.default_config.shortcuts[wf][mode][action] == nil then
                            print("The action " .. action .. " does not exists")
                        else
                            M.default_config.shortcuts[wf][mode][action][arg] = real_keys
                        end
                    end
                end
            end
        end
    end
end

M.apply_config = function(_config)
    local config = _config or M.default_config
    local wf = config.options.workflow
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
    require('azul').options = M.default_config.options
end

M.overwrite_default_action = function(action, wf, mode, shortcut)
    if not vim.tbl_contains(actions, action) then
        error("There is no action " .. action)
    end
    if not vim.tbl_contains({'azul', 'tmux', 'zellij', 'emacs'}, wf) then
        error("There is no workflow " .. wf)
    end
    if not vim.tbl_contains(vim.tbl_keys(modes), mode) then
        error("There is no mode " .. mode)
    end
    M.default_config.shortcuts[wf][mode][action] = shortcut
end

return M
