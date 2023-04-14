require('my-lualine')
local azul = require('azul')
local map = azul.set_key_map
local cmd = vim.api.nvim_create_autocmd

azul.set_modifier(nil)

cmd({'TermClose', 'TermEnter', 'WinEnter'}, {
    pattern = "*", callback = function()
        vim.fn.timer_start(1, function()
            vim.api.nvim_command('startinsert')
        end)
    end
})

local feedkeys = function(keys)
    local codes = vim.api.nvim_replace_termcodes('<C-\\><c-n>' .. keys, true, false, true)
    vim.api.nvim_feedkeys(codes, 't', false)
end

map('t', '<a-c>', '', {
    callback = function()
        feedkeys(':$tabnew<cr>')
    end
})

local tab_shortcut = function(n)
    map('t', '<a-' .. n .. '>', '', {
        callback = function()
            feedkeys(':tabn ' .. n .. '<cr>i')
        end
    })
end

for i = 1,9,1 do
    tab_shortcut(i)
end

map('t', '<a-w>', '', {
    callback = function()
        azul.toggle_floats()
        vim.api.nvim_command('startinsert')
    end
})

map('t', '<a-f>', '', {
    callback = function()
        azul.open_float()
    end
})

local set_hjkl_shortcuts = function(key, dir, callback)
    map('t', key, '', {
        callback = function()
            callback(dir)
        end
    })
end

local set_move_shortcuts = function(key, dir, inc)
    map('t', key, '', {
        callback = function()
            azul.move_current_float(dir, inc or 5, false)
        end
    })
end

local set_panel_shortcuts = function(key, dir)
    set_hjkl_shortcuts(key, dir, azul.select_next_term)
end

local set_split_shortcuts = function(key, dir)
    set_hjkl_shortcuts(key, dir, azul.split)
end

local set_position_shortcut = function(key, where)
    set_hjkl_shortcuts(key, where, azul.position_current_float)
end

local set_resize_shortcut = function(key, action)
    map('t', key, '', {
        callback = function()
            feedkeys(action)
        end
    })
end

set_move_shortcuts('<c-a-h>', 'left')
set_move_shortcuts('<c-a-j>', 'down')
set_move_shortcuts('<c-a-k>', 'up')
set_move_shortcuts('<c-a-l>', 'right')

set_panel_shortcuts('<a-h>', 'left')
set_panel_shortcuts('<a-j>', 'down')
set_panel_shortcuts('<a-k>', 'up')
set_panel_shortcuts('<a-l>', 'right')

set_split_shortcuts('<c-h>', 'left')
set_split_shortcuts('<c-j>', 'down')
set_split_shortcuts('<c-k>', 'up')
set_split_shortcuts('<c-l>', 'right')

set_position_shortcut('<c-a-n>', 'top')
set_position_shortcut('<c-a-e>', 'right')
set_position_shortcut('<c-a-s>', 'bottom')
set_position_shortcut('<c-a-w>', 'left')

vim.api.nvim_command('colorscheme ' .. (os.getenv('AZUL_COLORS') or 'tokyonight-night'))

set_resize_shortcut('<C-left>', ':vert res -5<cr>i')
set_resize_shortcut('<C-down>', ':res +5<cr>i')
set_resize_shortcut('<C-up>', ':res -5<cr>i')
set_resize_shortcut('<C-right>', ':vert res +5<cr>i')

map('t', '<a-n>', '', {
    callback = azul.toggle_nested_mode
})

vim.o.mouse = ""
vim.o.expandtab = true
vim.o.smarttab = true
vim.o.showtabline = false
vim.o.completeopt = "menu,menuone,noselect"
vim.o.wildmode = "longest,list"
