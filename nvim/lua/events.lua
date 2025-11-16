local funcs = require('functions')

local M = {}

local events = {
    FloatHidden = {},
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
    VesperStarted = {},
    ActionRan = {},
    ExitVesper = {},
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
    VesperConnected = {},
    HistoryChanged = {},
    PaneResized = {},
    FloatMoved = {},
    FloatsHistoryChanged = {},
    LayoutRestoringStarted = {},
    UndoFinished = {},
    TerminalAdded = {},
    FullscreenToggled = {},

    DirectoryChanged = {},
}

local persistent_events = {}

for k in pairs(events) do
    persistent_events[k] = {}
end

local event_id = 0

local add_event = function(ev, callback, where)
    local to_add = (type(ev) == 'string' and {ev}) or ev

    event_id = event_id + 1
    for _, e in ipairs(to_add) do
        if not vim.tbl_contains(vim.tbl_keys(events), e) then
            M.error(e .. " event does not exists", nil)
        end

        table.insert(where[e], {callback = callback, id = event_id})
    end

    return event_id
end

M.trigger_event = function(ev, args)
    for _, l in ipairs(persistent_events[ev] or {}) do
        if l.callback ~= nil then
            l.callback(args)
        end
    end

    for _, l in ipairs(events[ev] or {}) do
        if l.callback ~= nil then
            l.callback(args)
        end
    end
end

M.on = function(ev, callback)
    return add_event(ev, callback, events)
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
    return add_event(ev, callback, persistent_events)
end

M.single_shot = function(ev, callback)
    local L = {}
    L.id = add_event(ev, function(args)
        callback(args)
        M.clear_event(ev, L.id)
    end, events)
end

M.clear_event = function(ev, id)
    if not vim.tbl_contains(vim.tbl_keys(events), ev) then
        M.error(ev .. " event does not exists", nil)
    end

    if id == nil then
        events[ev] = {}
        return
    end

    events[ev] = vim.tbl_filter(function(c) return c.id ~= id end, events[ev])
end

M.error = function(msg, h)
    local _m = msg
    if h ~= nil then
        _m = _m .. " at " .. vim.inspect(h)
    end
    M.trigger_event("Error", {_m})
    -- The test environment will disable the throwing of errors
    if vim.g.vesper_errors_log ~= nil then
        funcs.log(vim.inspect(_m), vim.g.vesper_errors_log)
    else
        error(_m)
    end
end

return M
