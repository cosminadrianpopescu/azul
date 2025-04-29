local azul = require('azul')
local funcs = require('functions')
local options = require('options')

local mode_before_disconnected = nil

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

azul.persistent_on('EnterDisconnectedPane', function()
    mode_before_disconnected = azul.current_mode()
    if mode_before_disconnected == 'n' or mode_before_disconnected == 'a' or options.workflow == 'tmux' or mode_before_disconnected == 'M' then
        return
    end
    vim.fn.timer_start(1, function()
        funcs.log("REENTER " .. vim.inspect(mode_before_disconnected))
        azul.enter_mode(mode_before_disconnected)
    end)
end)

azul.persistent_on('LeaveDisconnectedPane', function()
    if mode_before_disconnected ~= 't' then
        return
    end

    -- azul.suspend()
    funcs.log("VIM MODE IS " .. vim.inspect(vim.fn.mode()))
        start_insert()
    -- azul.resume()
end)
