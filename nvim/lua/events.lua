local funcs = require('functions')
local ERRORS = require('error_handling')

local M = {}
local is_started = false
local events_buffer = {}

local events = {
    FloatHidden = {},
    ModeChanged = {},
    FloatsVisible = {},
    FloatOpened = {},
    PaneChanged = {},
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

    MouseClick = {},
    RemoteQuit = {},
    RemoteStartedScroll = {},
    RemoteEndedScroll = {},
    LayoutPanic = {},
    LayoutRecovered = {},
    CommandPaletteOpen = {},
    CommandPaletteClosed = {},
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
            ERRORS.throw(e .. " event does not exists", nil)
        end

        table.insert(where[e], {callback = callback, id = event_id})
    end

    return event_id
end

local run_events = function(ev, args, which)
    for _, l in ipairs(which[ev] or {}) do
        if l.callback ~= nil then
            ERRORS.try_execute(function()
                l.callback(args)
            end)
        end
    end
end

M.trigger_event = function(ev, args)
    if not is_started and ev ~= 'VesperStarted' then
        table.insert(events_buffer, {ev = ev, args = args})
        return
    end
    run_events(ev, args, persistent_events)
    run_events(ev, args, events)
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

M.persistent_on('VesperStarted', function()
    is_started = true
    ERRORS.defer(1, function()
        for _, ev in pairs(events_buffer) do
            M.trigger_event(ev.ev, ev.args)
        end
        events_buffer = {}
    end)
end)

M.single_shot = function(ev, callback)
    local id
    id = add_event(ev, function(args)
        callback(args)
        M.clear_event(ev, id)
    end, events)
end

M.clear_event = function(ev, id)
    if not vim.tbl_contains(vim.tbl_keys(events), ev) then
        ERRORS.throw(ev .. " event does not exists", nil)
    end

    if id == nil then
        events[ev] = {}
        return
    end

    events[ev] = vim.tbl_filter(function(c) return c.id ~= id end, events[ev])
end

vim.keymap.set({'n', 'i', 't'}, '<LeftRelease>', function()
    M.trigger_event('MouseClick', {vim.fn.getmousepos()})
end)

return M
