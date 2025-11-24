local M = {}

local files = require('files')
local split = require('split')
local funcs = require('functions')
local cmd = vim.api.nvim_create_autocmd
local tabs = 0
local options = require('options')
local env = require('environment')
local F = require('floats')
local R = require('remote')

M.ini_shortcuts = {}

cmd({'TabNew', 'VimEnter'}, {
    pattern = "*", callback = function()
        local core = require('core')
        if not options.link_floats_with_tabs then
            core.set_tab_variable('float_group', 'default')
            return
        end
        vim.fn.timer_start(1, function()
            core.set_tab_variable('float_group', 'tab-' .. tabs)
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
    'rename_tab', 'edit_scrollback', 'edit_scrollback_log', 'rename_float',
    'show_mode_cheatsheet', 'remote_scroll', 'undo', 'toggle_fullscreen',
}

local modes = {
    terminal = 't', vesper = 'a', resize = 'r', pane = 'p', move = 'm', split = 's', tabs = 'T', visual = 'v', passthrough = 'P',
    modifier = 'M',
}

M.default_config = {
    shortcuts = {
        vesper = {
            terminal = {
                paste = '<C-v>',
            },
            modifier = {
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
                    a = 'n',
                    v = 'v',
                    P = 'P',
                },
                create_float = 'f',
                disconnect = 'd',
                remote_scroll = '[',
                paste = 'pp',
                undo = 'u',
                toggle_fullscreen = 'F',
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
                rename_float = 'r',
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
            modifier = {
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
                remote_scroll = '[',
                paste = 'pp',
                undo = 'u',
                toggle_fullscreen = 'F',
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
                rename_float = 'r',
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
                    a = '<C-a>',
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
                rename_float = 'r',
                remote_scroll = '[',
                toggle_fullscreen = 'F',
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
                undo = 'u',
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
                rename_float = '<C-x><C-f>',
                edit_scrollback = '<C-x><C-e>',
                edit_scrollback_log = '<C-x>ge',
                remote_scroll = '<C-x>[',
                undo = '<C-z>',
                toggle_fullscreen = '<F11>',
            },
        }
    }
}

local set_shortcut = function(action, shortcut, mode, arg)
    table.insert(M.ini_shortcuts, {action = action, shortcut = shortcut, mode = mode, arg = arg})
    local core = require('core')
    local map = core.set_key_map
    local map2 = vim.api.nvim_set_keymap
    local wf = core.get_current_workflow()

    local t = function(key, callback, what)
        map(mode, key, '', {
            callback = function()
                local opts = require('telescope.themes').get_ivy({})
                callback(opts)
            end,
            desc = "Select a " .. what,
            action = action,
            arg = arg,
        })
    end

    if action == 'select_terminal' or action == 'select_session' then
        local callback = (action == 'select_terminal' and require('select').term_select) or require('select').sessions_list
        t(shortcut, callback, action:gsub('select_', ''))
    elseif action == 'create_tab' then
        map(mode, shortcut, '', {
            callback = function()
                if funcs.is_handling_remote() then
                    R.create_tab_remote()
                else
                    core.create_tab()
                end
            end,
            desc = 'Creates a new tab',
            action = action,
            arg = arg,
        })
    elseif action == 'tab_select' then
        map(mode, shortcut, '', {
            callback = function()
                core.select_tab(arg)
            end,
            desc = 'Go to tab ' .. arg,
            action = action,
            arg = arg,
        })
    elseif action == 'toggle_floats' then
        map(mode, shortcut, '', {
            callback = function()
                F.toggle_floats(funcs.current_float_group())
            end,
            desc = "Toggle floats visibility",
            action = action,
            arg = arg,
        })
    elseif action == 'enter_mode' then
        local mapping = {
            p = 'pane',
            r = 'resize',
            m = 'move',
            s = 'split',
            T = 'tabs',
            t = 'terminal',
            a = 'vesper',
            v = 'visual',
            P = 'passthrough',
        }
        if arg == 'n' or arg == 'v' or arg == 'a' then
            if (mode == 'n' or mode == 'a') and arg == 'v' then
                return
            end
            local suf = (arg == 'v' and 'v') or ''
            map(mode, shortcut, '', {
                callback = function()
                    core.enter_mode('a')
                    vim.api.nvim_command('stopinsert')
                    if suf ~= '' then
                        core.feedkeys(suf, 't')
                    end
                end,
                desc = 'Enter ' .. mapping[arg] .. ' mode',
            })
            return
        end
        map(mode, shortcut, '', {
            callback = function()
                core.enter_mode(arg)
            end,
            desc = "Enter " .. mapping[arg] .. " mode",
            action = action,
            arg = arg,
        })
    elseif action == 'create_float' then
        map(mode, shortcut, '', {
            callback = function()
                if funcs.is_handling_remote() then
                    R.open_float_remote()
                else
                    F.open_float()
                end
            end,
            desc = "Create float",
            action = action,
            arg = arg,
        })
    elseif action == 'disconnect' then
        map(mode, shortcut, '', {
            callback = core.disconnect,
            desc = "Disconnect",
            action = action,
            arg = arg,
        })
    elseif action == 'resize_left' or action == 'resize_right' or action == 'resize_down' or action == 'resize_up' then
        local where = action:gsub('resize_', '')
        map(mode, shortcut, '', {
            callback = function()
                core.resize(where)
            end,
            desc = "Resize " .. where,
            action = action,
            arg = arg,
        })
    elseif action == 'select_left' or action == 'select_right' or action == 'select_down' or action == 'select_up' then
        local dir = action:gsub('select_', '')
        map(mode, shortcut, '', {
            callback = function()
                core.select_next_pane(dir, funcs.current_float_group())
            end,
            desc = 'Select a pane ' .. dir,
            action = action,
            arg = arg,
        })
    elseif action == 'move_left' or action == 'move_right' or action == 'move_up' or action == 'move_down' then
        local dir = action:gsub('move_', '')
        map(mode, shortcut, '', {
            callback = function()
                F.move_current_float(dir, arg)
            end,
            desc = 'Move a panel to ' .. dir,
            action = action,
            arg = arg,
        })
    elseif action == 'split_left' or action == 'split_right' or action == 'split_up' or action == 'split_down' then
        local dir = action:gsub('split_', '')
        map(mode, shortcut, '', {
            callback = function()
                if funcs.is_handling_remote() then
                    R.split_remote(false, dir)
                else
                    core.split(dir)
                end
            end,
            desc = 'Split ' .. dir,
            action = action,
            arg = arg,
        })
    elseif action == 'move_top' or action == 'move_bottom' or action == 'move_start' or action == 'move_end' then
        local dir = action:gsub('move_', '')
        map(mode, shortcut, '', {
            callback = function()
                F.position_current_float(dir)
            end,
            desc = 'Move current pane to ' .. dir,
            action = action,
            arg = arg,
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
            arg = arg,
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
        local callback = (wf == 'vesper' and mode == 't' and shortcut:match('^<.*>$') and map2) or map
        callback(mode, shortcut, '', {
            callback = core.paste_from_clipboard,
            desc = 'Paste from clipboard',
        })
    elseif action == 'passthrough' then
        map(mode, shortcut, '', {
            callback = function()
                core.toggle_passthrough()
            end,
            desc = 'Toggle passthrough mode',
            action = action,
            arg = arg,
        })
    elseif action == 'rotate_panel' then
        map(mode, shortcut, '', {
            callback = function()
                core.rotate_panel()
            end,
            desc = 'Rotates the current panel',
            action = action,
            arg = arg,
        })
    elseif action == 'rename_tab' then
        map(mode, shortcut, '', {
            callback = function()
                vim.defer_fn(core.rename_current_tab, 1);
            end,
            desc = 'Renames the current tab',
            action = action,
            arg = arg,
        })
    elseif action == 'rename_float' then
        map(mode, shortcut, '', {
            callback = F.rename_current_pane,
            desc = 'Renames the current floating pane',
            action = action,
            arg = arg,
        })
    elseif action == 'edit_scrollback' then
        map(mode, shortcut, '', {
            callback = function()
                core.edit_current_scrollback()
                core.enter_mode('t')
            end,
            desc = 'Edits the scrollback buffer',
            action = action,
            arg = arg,
        })
    elseif action == 'edit_scrollback_log' then
        map(mode, shortcut, '', {
            callback = function()
                core.edit_current_scrollback_log()
                core.enter_mode('t')
            end,
            desc = 'Edits the scrollback log',
            action = action,
            arg = arg,
        })
    elseif action == 'show_mode_cheatsheet' then
        map(mode, shortcut, '', {
            callback = function()
            end,
            desc = "All shortcuts",
            action = action,
            arg = arg,
        })
    elseif action == 'remote_scroll' then
        map(mode, shortcut, '', {
            callback = R.remote_enter_scroll_mode,
            desc = "Scroll a remote pane",
            action = action,
            arg = arg,
        })
    elseif action == 'undo' then
        map(mode, shortcut, '', {
            callback = function()
                require('undo').undo()
            end,
            desc = 'Restores last closed pane',
            action = action,
            arg = arg,
        })
    elseif action == 'toggle_fullscreen' then
        map(mode, shortcut, '', {
            callback = function()
                require('floats').toggle_fullscreen(require('core').get_current_terminal())
            end,
            desc = 'Toggles the fullscreen state',
            action = action,
            arg = arg,
        })
    end
end

local set_key_value = function(section, default)
    local result = default or {}
    for key, value in pairs(section) do
        if value == 'true' then
            value = true
        elseif value == 'false' then
            value = false
        elseif tonumber(value) ~= nil then
            value = tonumber(value)
        end
        result[key] = value
    end

    return result
end

M.load_config = function(where)
    local t = files.read_ini(where)
    if t.options ~= nil then
        options = set_key_value(t.options, options)
    end

    local wf = options.workflow

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

    if t.environment ~= nil then
        env.set_environment(set_key_value(t.environment))
    end
end

M.set_shortcuts = function(shortcuts)
    M.ini_shortcuts = {}
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

    for mode, collection in pairs(shortcuts) do
        do_setshortcut(collection, modes[mode])
    end
end

M.apply_config = function(_config)
    if files.exists(files.config_dir .. '/config.ini') then
        M.load_config(files.config_dir .. '/config.ini')
    end
    require('core').set_workflow(options.workflow, options.modifier)

    local config = _config or M.default_config
    local wf = options.workflow
    M.set_shortcuts(config.shortcuts[wf])
end

M.overwrite_default_action = function(action, wf, mode, shortcut)
    if not vim.tbl_contains(actions, action) then
        error("There is no action " .. action)
    end
    if not vim.tbl_contains({'vesper', 'tmux', 'zellij', 'emacs'}, wf) then
        error("There is no workflow " .. wf)
    end
    if not vim.tbl_contains(vim.tbl_keys(modes), mode) then
        error("There is no mode " .. mode)
    end
    local old = M.default_config.shortcuts[wf][mode][action]
    if old ~= nil then
        require('core').remove_key_map(modes[mode], old)
    end
    M.default_config.shortcuts[wf][mode][action] = shortcut
end

M.set_vim_options = function()
    vim.o.cmdheight = tonumber(options.cmdheight)
    vim.o.scrollback = options.scrollback
    vim.o.termguicolors = options.termguicolors
    vim.o.mouse = options.mouse
    if options.shell then
        vim.o.shell = options.shell
    end
    vim.o.clipboard = options.clipboard
    vim.o.encoding = options.encoding
    vim.o.winblend = options.opacity
    vim.o.number = false
    vim.o.relativenumber = false
    vim.o.belloff = "all"
    vim.o.laststatus = 3
    vim.o.bufhidden = "hide"
    vim.o.hidden = true

    -- vim.o.expandtab = true
    -- vim.o.smarttab = true
    vim.o.showtabline = 0
    -- vim.o.completeopt = "menu,menuone,noselect"
    -- vim.o.wildmode = "longest,list"
    vim.o.timeout = true
    vim.o.timeoutlen = 300
end

M.run_init_lua = function()
    local config_file = files.config_dir .. '/init.lua'
    if not files.try_load_config(config_file) then
        files.try_load_config(files.config_dir .. '/init.vim')
    end
end

M.reload_config = function()
    if options.workflow == 'tmux' or options.workflow == 'vesper' then
        local cmd = 'tunmap ' .. options.modifier
        pcall(function() vim.api.nvim_command(cmd) end)
    end
    local core = require('core')
    core.clear_mappings()
    M.apply_config()
    M.set_vim_options()
    M.run_init_lua()
    vim.fn.timer_start(1, function()
        core.update_titles()
        require('events').trigger_event('ConfigReloaded')
    end)
end

M.edit_config = function()
    if not files.exists(files.config_dir .. '/config.ini') then
        return
    end
    local core = require('core')
    core.edit(core.get_current_terminal(), files.config_dir .. '/config.ini', M.reload_config)
end

return M
