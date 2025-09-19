local funcs = require('functions')

local M = {}

local events = {
    FloatClosed = {},
    ModeChanged = {},
    FloatsVisible = {},
    FloatOpened = {},
    PaneChanged = {},
    Error = {},
    PaneClosed = {},
    LayoutSaved = {},
    LayoutRestored = {},
    WinConfigChanged = {},
    TabTitleChanged = {},
    AzulStarted = {},
    ActionRan = {},
    ExitAzul = {},
    FloatTitleChanged = {},
    ConfigReloaded = {},
    RemoteDisconnected = {},
    RemoteReconnected = {},
    UserInput = {},
    UserInputPrompt = {},
    Edit = {},
    LeaveDisconnectedPane = {},
    EnterDisconnectedPane = {},
    TabCreated = {},
    CommandSet = {},
    WinIdSet = {},
    AzulConnected = {},

    HistoryChanged = {},
    PaneResized = {},
    FloatMoved = {},
}

local persistent_events = {}

for k in pairs(events) do
    persistent_events[k] = {}
end

local add_event = function(ev, callback, where)
    local to_add = (type(ev) == 'string' and {ev}) or ev

    for _, e in ipairs(to_add) do
        if not vim.tbl_contains(vim.tbl_keys(events), e) then
            M.error(e .. " event does not exists", nil)
        end

        table.insert(where[e], callback)
    end
end

M.trigger_event = function(ev, args)
    for _, callback in ipairs(persistent_events[ev] or {}) do
        callback(args)
    end

    for _, callback in ipairs(events[ev] or {}) do
        callback(args)
    end
end

M.on = function(ev, callback)
    add_event(ev, callback, events)
end

M.on_action = function(action, callback)
    M.on('ActionRan', function(args)
        if args[1] ~= action then
            return
        end
        callback(args[1])
    end)
end

M.persistent_on = function(ev, callback)
    add_event(ev, callback, persistent_events)
end

M.clear_event = function(ev, callback)
    if not vim.tbl_contains(vim.tbl_keys(events), ev) then
        M.error(ev .. " event does not exists", nil)
    end
    if callback == nil then
        events[ev] = {}
        return
    end

    events[ev] = vim.tbl_filter(function(c) return c == callback end, events[ev])
end

M.error = function(msg, h)
    local _m = msg
    if h ~= nil then
        _m = _m .. " at " .. vim.inspect(h)
    end
    M.trigger_event("Error", {_m})
    -- The test environment will disable the throwing of errors
    if vim.g.azul_errors_log ~= nil then
        funcs.log(vim.inspect(_m), vim.g.azul_errors_log)
    else
        error(_m)
    end
end

return M
