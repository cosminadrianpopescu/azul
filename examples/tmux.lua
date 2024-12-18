local azul = require('azul')
local u = require('utils')
local map = azul.set_key_map
local cmd = vim.api.nvim_create_autocmd

azul.set_workflow('tmux')

local float_group = function()
    return vim.t.float_group or 'default' -- we can set on a tab the t:float_group variable and
                                          -- then all the floats on that tab
                                          -- will be assigned to the t:float_group group
end

cmd('TermClose', {
    pattern = "*", callback = function()
        vim.fn.timer_start(1, function()
            vim.fn.feedkeys('i')
        end)
    end
})

map('n', 'c', '', {
    callback = function()
        azul.open()
        vim.fn.timer_start(1, function()
            vim.api.nvim_command('startinsert')
        end)
    end
})

local set_mode_escape = function(shortcut)
    map({'r', 'p', 'm', 's', 'T'}, shortcut, '', {
        callback = function()
            azul.enter_mode('n')
            vim.fn.timer_start(1, function()
                vim.api.nvim_command('startinsert')
            end)
        end
    })
end

local tab_shortcut = function(n)
    map('n', n .. '', '', {
        callback = function()
            local hidden = azul.are_floats_hidden(float_group())
            if not hidden then
                azul.hide_floats()
            end
            vim.api.nvim_command('tabn ' .. n)
            vim.api.nvim_command('startinsert')
            if not hidden then
                azul.show_floats(float_group())
            end
        end
    })
end

for i = 1,9,1 do
    tab_shortcut(i)
end

map('n', 'w', '', {
    callback = function()
        azul.toggle_floats(float_group())
        vim.fn.timer_start(1, function()
            vim.api.nvim_command('startinsert')
        end)
    end
})

local enter_mode_mapping = function(mode)
    map('n', mode, '', {
        callback = function()
            azul.enter_mode(mode)
        end
    })
end

map('n', 'f', '', {
    callback = function()
        azul.open_float(float_group())
        vim.fn.timer_start(1, function()
            vim.api.nvim_command('startinsert')
        end)
    end
})

enter_mode_mapping('p')
enter_mode_mapping('r')
enter_mode_mapping('m')
enter_mode_mapping('s')
enter_mode_mapping('T')

set_mode_escape('<cr>')
set_mode_escape('<esc>')

local options = {noremap = true}
map('c', '<C-n>', '<Down>', options)
map('c', '<C-p>', '<Up>', options)
map('n', 'd', '', {
    callback = azul.disconnect,
})

local set_move_shortcuts = function(key, dir, inc)
    map('m', key, '', {
        callback = function()
            azul.move_current_float(dir, inc or 5)
        end
    })
end

local set_hjkl_shortcuts = function(key, dir, mode, callback)
    map(mode, key, '', {
        callback = function()
            callback(dir, float_group())
        end
    })
end

local set_tabs_shortcuts = function(key, where)
    map('T', key, '', {
        callback = function()
            if where:match('open') then
                azul.enter_mode('t')
                azul.open()
            else
                vim.api.nvim_command(where)
            end
        end
    })
end

local set_panel_shortcuts = function(key, dir)
    set_hjkl_shortcuts(key, dir, 'p', azul.select_next_pane)
end

local set_panel_split_shortcuts = function(key, dir)
    set_hjkl_shortcuts(key, dir, 'p', azul.split)
end

local set_split_shortcuts = function(key, dir)
    set_hjkl_shortcuts(key, dir, 's', azul.split)
end

local set_resize_shortcuts = function(key, which)
    map('r', key, '', {
        callback = function()
            vim.api.nvim_command(which)
        end
    })
end

local set_position_shortcut = function(key, where)
    map('n', key, '', {
        callback = function()
            azul.position_current_float(where)
        end
    })
end

set_tabs_shortcuts('H', 'tabfirst')
set_tabs_shortcuts('L', 'tablast')
set_tabs_shortcuts('h', 'tabprev')
set_tabs_shortcuts('l', 'tabnext')
set_tabs_shortcuts('c', 'open')

set_move_shortcuts('h', 'left')
set_move_shortcuts('j', 'down')
set_move_shortcuts('k', 'up')
set_move_shortcuts('l', 'right')

set_panel_shortcuts('h', 'left')
set_panel_shortcuts('j', 'down')
set_panel_shortcuts('k', 'up')
set_panel_shortcuts('l', 'right')

set_panel_split_shortcuts('H', 'left')
set_panel_split_shortcuts('J', 'down')
set_panel_split_shortcuts('K', 'up')
set_panel_split_shortcuts('L', 'right')

set_split_shortcuts('h', 'left')
set_split_shortcuts('j', 'down')
set_split_shortcuts('k', 'up')
set_split_shortcuts('l', 'right')

set_move_shortcuts('<c-h>', 'left', 1)
set_move_shortcuts('<c-j>', 'down', 1)
set_move_shortcuts('<c-k>', 'up', 1)
set_move_shortcuts('<c-l>', 'right', 1)

set_position_shortcut('K', 'top')
set_position_shortcut('L', 'end')
set_position_shortcut('J', 'bottom')
set_position_shortcut('H', 'start')

set_resize_shortcuts('h', 'vert res -5')
set_resize_shortcuts('j', 'res +5')
set_resize_shortcuts('k', 'res -5')
set_resize_shortcuts('l', 'vert res +5')

map('n', '<space>P', '', {
    callback = function()
        u.paste_from_clipboard()
        vim.fn.timer_start(1, function()
            vim.api.nvim_command('startinsert')
        end)
    end,
})

map('n', '<space>p', '', {
    callback = function()
        u.paste()
        vim.fn.timer_start(1, function()
            vim.api.nvim_command('startinsert')
        end)
    end,
})

map('n', '<c-l>', '<c-\\><c-n>:redraw!<cr><c-l>:lua require("azul").redraw()<cr>i', {})
map('n', 'N', '', {
    callback = azul.toggle_nested_mode
})

vim.o.mouse = ""
vim.o.expandtab = true
vim.o.smarttab = true
vim.o.showtabline = 0
vim.o.completeopt = "menu,menuone,noselect"
vim.o.wildmode = "longest,list"

map('p', 'x', '', {
    callback = function()
        azul.rotate_panel()
    end
})
