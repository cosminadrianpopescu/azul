local history = {}
local EV = require('events')
local funcs = require('functions')

local M = {}

M.add_to_history = function(t, operation, params, tab_id)
    if funcs.is_float(t) then
        local el = {
            operation = operation,
            params = params,
            buf = t.buf,
            term = t,
        }
        EV.trigger_event('FloatsHistoryChanged', {el})
        return
    end
    local el = {
        operation = operation,
        params = params,
        to = (operation == "split" and -1) or nil,
        tab_id = tab_id,
        buf = t.buf,
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

M.debug = function()
    vim.fn.timer_start(1, function()
        funcs.log("HISTORY IS " .. vim.inspect(history))
    end)
end

return M
