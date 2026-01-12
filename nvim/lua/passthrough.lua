local core = require('core')
local options = require('options')
local funcs = require('functions')
local EV = require('events')

local M = {}
local children = {}

M.register_child = function(id, panel_id)
    table.insert(children, {panel_id = panel_id, child_session_id = id})
end

M.unregister_child = function(id, panel_id)
    children = vim.tbl_filter(function(c) return c.panel_id .. "" ~= panel_id .. "" and c.child_session_id .. "" ~= id .. "" end, children)
end

local is_active = function(session_id, callback)
    local path = os.getenv('VESPER_RUN_DIR') .. '/' .. session_id
    if vim.uv.fs_stat(path) == nil then
        return callback(false)
    end

    local sock = vim.uv.new_pipe(false)
    sock:connect(path, function(err)
        vim.schedule_wrap(function()
            callback(err == nil)
        end)()
        sock:close()
    end)
end

local set_map = function(escape)
    core.set_key_map('P', escape or options.passthrough_escape, '', {
        callback = function()
            M.toggle_passthrough(escape)
        end
    })
end

local has_child_session = function(callback)
    local t = core.get_current_terminal()
    if t == nil then
        return callback(false)
    end
    local c = funcs.find(function(c2) return c2.panel_id .. "" == t.panel_id .. "" end, children)
    if c == nil then
        return callback(false)
    end

    return is_active(c.child_session_id, callback)
end

--- Toggles passthrough mode
--- @param escape string|nil Escape sequence
M.toggle_passthrough = function(escape)
    if core.current_mode() ~= 'P' then
        set_map(escape)
        core.enter_mode('P')
    else
        has_child_session(function(result)
            if result then
                core.send_to_current(escape or options.passthrough_escape, true)
                return
            end

            core.enter_mode('t')
            core.remove_key_map('P', escape or options.passthrough_escape)
        end)
    end
end

local send_to_parent = function(cmd)
    vim.fn.jobstart(
        os.getenv('VESPER_PREFIX') .. '/bin/vesper -a ' .. os.getenv('VESPER_PARENT_SESSION')
        .. ' -r "' .. vim.inspect(cmd) .. ' ' .. os.getenv('VESPER_SESSION') .. ' ' .. os.getenv('VESPER_PARENT_PANEL_ID') .. '"')
end

EV.persistent_on('ModeChanged', function(args)
    if os.getenv('VESPER_PARENT_SESSION') == nil or os.getenv('VESPER_PARENT_PANEL_ID') == nil then
        return
    end
    local new_mode = args[2]
    if new_mode ~= 'P' then
        send_to_parent('IVesperUnregisterChild')
        return
    end
    send_to_parent('IVesperRegisterChild')
    set_map()
end)

M.debug = function()
    funcs.log(vim.inspect(children))
end

return M
