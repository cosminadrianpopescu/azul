local EV = require('events')
local core = require('core')
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

local do_start_insert = function()
    vim.fn.timer_start(100, function()
        start_insert(true)
    end)
end

EV.persistent_on({
    'UserInputPrompt', 'UserInput', 'RemoteDisconnected', 'PaneClosed', 'Edit',
    'VesperStarted', 'FloatOpened', 'RemoteReconnected', 'TabCreated', 'CommandSet',
    'WinIdSet', 'ConfigReloaded', 'VesperConnected', 'Error', 'LayoutRestored',
    'UndoFinished', 'FullscreenToggled', 'DirectoryChanged',
}, do_start_insert)

EV.persistent_on({'MouseClick', 'RemoteStartedScroll'}, function()
    start_insert(true)
end)

EV.persistent_on('LayoutSaved', function(args)
    if args[2] == true then
        return
    end
    do_start_insert()
end)

EV.persistent_on('ModeChanged', function(args)
    local new_mode = args[2]
    if new_mode ~= 't' and new_mode ~= 'P' then
        return
    end
    vim.fn.timer_start(50, function()
        start_insert(true)
    end)
end)

EV.persistent_on('EnterDisconnectedPane', function()
    mode_before_disconnected = core.current_mode()
    if mode_before_disconnected == 'n' or mode_before_disconnected == 'a' or options.workflow == 'tmux' or mode_before_disconnected == 'M' then
        return
    end
    vim.fn.timer_start(1, function()
        core.enter_mode(mode_before_disconnected)
    end)
end)

EV.persistent_on('LeaveDisconnectedPane', function()
    if mode_before_disconnected ~= 't' then
        return
    end

    start_insert()
end)

EV.persistent_on('UserInputPrompt', function()
    is_editing = true
end)

EV.persistent_on({'UserInput', 'Error'}, function()
    is_editing = false
end)

M.is_editing = function()
    return is_editing
end

return M
