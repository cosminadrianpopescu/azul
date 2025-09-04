local azul = require('azul')
local options = require('options')

local mode_before_disconnected = nil

local M = {}
local is_editing = false

local start_insert = function(force)
    if options.workflow == 'tmux' and not force then
        return
    end
    vim.api.nvim_command('startinsert')
end

azul.persistent_on({
    'UserInputPrompt', 'UserInput', 'RemoteDisconnected', 'PaneClosed', 'Edit',
    'AzulStarted', 'FloatOpened', 'RemoteReconnected', 'TabCreated', 'CommandSet',
    'WinIdSet', 'ConfigReloaded', 'AzulConnected', 'Error'
}, function()
    vim.fn.timer_start(100, function()
        start_insert(true)
    end)
end)

azul.persistent_on('ModeChanged', function(args)
    local new_mode = args[2]
    if new_mode ~= 't' and new_mode ~= 'P' then
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
        azul.enter_mode(mode_before_disconnected)
    end)
end)

azul.persistent_on('LeaveDisconnectedPane', function()
    if mode_before_disconnected ~= 't' then
        return
    end

    start_insert()
end)

azul.persistent_on('UserInputPrompt', function()
    is_editing = true
end)

azul.persistent_on({'UserInput', 'Error'}, function()
    is_editing = false
end)

M.is_editing = function()
    return is_editing
end

return M
