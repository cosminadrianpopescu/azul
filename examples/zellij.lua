local azul = require('azul')
local map = azul.set_key_map
local cmd = vim.api.nvim_create_autocmd

azul.set_workflow('zellij')

require('bufresize').setup()

cmd('TermClose', {
    pattern = "*", callback = function()
        vim.fn.timer_start(1, function()
            vim.fn.feedkeys('i')
        end)
    end
})

map('p', 'c', '', {
    callback = function()
        azul.open()
    end,
})

map('p', 'H', '', {
    callback = function()
        vim.api.nvim_command('tabprev')
    end,
})

map('p', 'L', '', {
    callback = function()
        vim.api.nvim_command('tabnext')
    end,
})

map('p', 'w', '', {
    callback = function()
        azul.toggle_floats()
        vim.api.nvim_command('startinsert')
    end,
})

local enter_mode_mapping = function(key, mode)
    map('t', key, '', {
        callback = function()
            azul.enter_mode(mode)
        end
    })
end

map('p', 'f', '', {
    callback = function()
        azul.open_float()
        vim.fn.timer_start(1, function()
            azul.enter_mode('t')
            vim.api.nvim_command('startinsert')
        end)
    end,
})

enter_mode_mapping('<c-p>', 'p')
enter_mode_mapping('<c-r>', 'r')
enter_mode_mapping('<c-v>', 'm')
enter_mode_mapping('<c-s>', 's')
enter_mode_mapping('<c-t>', 'T')

map({'r', 'p', 'm', 's', 'T'}, '<esc>', '', {
    callback = function()
        azul.enter_mode('t')
        vim.fn.timer_start(1, function()
            vim.api.nvim_command('startinsert')
        end)
    end,
})

map('t', '<C-a>', '<C-\\><C-n>', {
    desc = 'Enter normal mode',
})

local options = {noremap = true}
map('c', '<C-n>', '<Down>', options)
map('c', '<C-p>', '<Up>', options)
map('t', '<c-d>', '', {
    callback = azul.disconnect,
})

local set_move_shortcuts = function(key, dir, inc)
    map('m', key, '', {
        callback = function()
            azul.move_current_float(dir, inc or 5)
        end,
    })
end

local set_hjkl_shortcuts = function(key, dir, mode, callback)
    map(mode, key, '', {
        callback = function()
            callback(dir)
        end,
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

set_split_shortcuts('h', 'left')
set_split_shortcuts('j', 'down')
set_split_shortcuts('k', 'up')
set_split_shortcuts('l', 'right')

set_resize_shortcuts('h', 'vert res -5')
set_resize_shortcuts('j', 'res +5')
set_resize_shortcuts('k', 'res -5')
set_resize_shortcuts('l', 'vert res +5')

map({'n', 't'}, '<a-n>', '', {
    callback = azul.toggle_nested_mode
})

vim.o.mouse = ""
vim.o.expandtab = true
vim.o.smarttab = true
vim.o.showtabline = 0
vim.o.completeopt = "menu,menuone,noselect"
vim.o.wildmode = "longest,list"

