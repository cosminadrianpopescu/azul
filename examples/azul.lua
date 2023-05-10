require('my-lualine')
local azul = require('azul')
local u = require('utils')
local map = azul.set_key_map
local map2 = vim.api.nvim_set_keymap
local cmd = vim.api.nvim_create_autocmd

azul.set_modifier(nil)

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
        vim.fn.timer_start(1, function()
            vim.fn.feedkeys('i')
        end)
    end
})

map2('t', '<C-s>c', '', {
    callback = function()
        feedkeys('')
        vim.api.nvim_command('$tabnew')
        vim.fn.timer_start(1, function()
            vim.api.nvim_command('startinsert')
        end)
    end,
    desc = "Create new tab",
})

local set_mode_escape = function(shortcut)
    map({'r', 'p', 'm', 's'}, shortcut, '', {
        callback = function()
            azul.enter_mode('t')
        end,
        base_mode = 't',
    })
end

local tab_shortcut = function(n)
    map2('t', '<C-s>'.. n, '', {
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
        end,
        desc = 'Go to tab ' .. n
    })
end

for i = 1,9,1 do
    tab_shortcut(i)
end

map2('t', '<C-s>w', '', {
    callback = function()
        azul.toggle_floats(float_group())
        vim.api.nvim_command('startinsert')
    end,
    desc = "Toggle floats visibility",
})

local enter_mode_mapping = function(mode)
    local mapping = {
        p = 'pane',
        r = 'resize',
        m = 'move',
        s = 'split'
    }
    map2('t', '<C-s>' .. mode, '', {
        callback = function()
            azul.enter_mode(mode)
        end,
        desc = "Enter " .. mapping[mode] .. " mode"
    })
end

map2('t', '<c-s>f', '', {
    callback = function()
        azul.open_float(float_group())
        vim.fn.timer_start(1, function()
            vim.api.nvim_command('startinsert')
        end)
    end,
    desc = "Create float"
})

enter_mode_mapping('p')
enter_mode_mapping('r')
enter_mode_mapping('m')
enter_mode_mapping('s')

set_mode_escape('<cr>')
set_mode_escape('<esc>')

local options = {noremap = true}
map2('c', '<C-n>', '<Down>', options)
map2('c', '<C-p>', '<Up>', options)

local set_move_shortcuts = function(key, dir, inc)
    map('m', key, '', {
        callback = function()
            azul.move_current_float(dir, inc or 5)
        end,
        base_mode = 't',
    })
end

local set_hjkl_shortcuts = function(key, dir, mode, callback)
    map(mode, key, '', {
        callback = function()
            callback(dir, float_group())
        end,
        base_mode = 't',
    })
end

local set_panel_shortcuts = function(key, dir)
    set_hjkl_shortcuts(key, dir, 'p', azul.select_next_term)
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
        end,
        base_mode = 't',
    })
end

local set_position_shortcut = function(key, where)
    map('m', key, '', {
        callback = function()
            azul.position_current_float(where)
        end,
        base_mode = 't',
    })
end

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
set_position_shortcut('L', 'right')
set_position_shortcut('J', 'bottom')
set_position_shortcut('H', 'left')

vim.api.nvim_command('colorscheme ' .. (os.getenv('AZUL_COLORS') or 'tokyonight-night'))

set_resize_shortcuts('h', 'vert res -5')
set_resize_shortcuts('j', 'res +5')
set_resize_shortcuts('k', 'res -5')
set_resize_shortcuts('l', 'vert res +5')

map('n', '<space>P', '', {
    callback = function()
        u.paste_from_clipboard()
        vim.api.nvim_command('startinsert')
    end,
})

map('n', '<space>p', '', {
    callback = function()
        u.paste()
        vim.api.nvim_command('startinsert')
        -- feedkeys(' <bs>')
    end,
})

map('t', '<c-l>', '<c-s><c-l>i', {})

map({'n', 't'}, '<a-n>', '', {
    callback = azul.toggle_nested_mode
})

vim.o.mouse = ""
vim.o.expandtab = true
vim.o.smarttab = true
vim.o.showtabline = false
vim.o.completeopt = "menu,menuone,noselect"
vim.o.wildmode = "longest,list"
vim.o.timeout = true
vim.o.timeoutlen = 300
local wk = require('which-key')
wk.setup({
    -- triggers = {'<c-s>'}
    triggers_no_wait = {
        '<C-s>'
    }
})
wk.register({
    ["<C-s>"] = {
        ['<cr>'] = {'', 'Cancel'},
        i = {'', 'Cancel'},
        n = {'<C-\\><C-n>', 'Enter normal mode'}
    }
}, {
    mode = "t",
})