local history = {}
local EV = require('events')
local funcs = require('functions')

local M = {}

M.add_to_history = function(t, operation, params, tab_id)
    if t == nil or funcs.is_float(t) then
        return
    end
    local el = {
        operation = operation,
        params = params,
        to = (operation == "split" and -1) or nil,
        tab_id = tab_id,
    }
    if operation == "create" then
        el.to = t.panel_id
    else
        el.from = t.panel_id
    end
    table.insert(history, el)

    EV.trigger_event('HistoryChanged', {el})
end

M.reset_history = function()
    history = {}
end

M.get_history = function()
    return history
end

return M
