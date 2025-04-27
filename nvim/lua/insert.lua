local azul = require('azul')
local funcs = require('functions')
local options = require('options')

local start_insert = function(force)
    funcs.log("STARTING INSERT" .. vim.fn.mode())
    if options.workflow == 'tmux' and not force then
        return
    end
    -- if vim.fn.mode() == 'n' and azul.remote_state(azul.get_current_terminal()) ~= 'disconnected' then
    --     azul.feedkeys('<esc>', 'n')
    --     azul.feedkeys('i', 'n')
    -- end
    vim.api.nvim_command('startinsert')
    vim.fn.timer_start(50, function()
        funcs.log("AND AFTER " .. vim.fn.mode())
    end)
end

azul.persistent_on({'UserInputPrompt', 'UserInput', 'RemoteDisconnected', 'PaneClosed', 'Edit', 'AzulStarted', 'FloatOpened'}, function()
    vim.fn.timer_start(50, function()
        start_insert(true)
    end)
end)

azul.persistent_on('ModeChanged', function(args)
    local new_mode = args[2]
    if new_mode ~= 't' then
        return
    end
    vim.fn.timer_start(50, function()
        start_insert(true)
    end)
end)
