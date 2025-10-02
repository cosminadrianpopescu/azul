local funcs = require('functions')
local core = require('core')
local EV = require('events')
local TABS = require('tab_vars')

local current_group = nil

local M = {}

local restore_float = function(t)
    if t == nil or not vim.api.nvim_buf_is_valid(funcs.get_real_buffer(t)) then
        return
    end
    vim.api.nvim_open_win(funcs.get_real_buffer(t), true, t.win_config)
    if t.editing_buf == nil then
        core.refresh_buf(t.buf)
    else
        t.win_id = vim.fn.win_getid(vim.fn.winnr())
    end
end

local rebuild_zindex_floats = function()
    local floats = funcs.get_visible_floatings(core.get_terminals())
    table.sort(floats, function(a, b) return a.last_access < b.last_access end)
    for i, f in ipairs(floats) do
        f.win_config.zindex = i
        if f.win_id ~= nil then
            vim.api.nvim_win_set_config(f.win_id, f.win_config)
        end
    end
end

local close_float = function(float)
    core.refresh_win_config(float)
    funcs.safe_close_window(float.win_id)
    float.win_id = nil
    vim.fn.timer_start(1, function()
        local t = core.get_current_terminal()
        if t == nil then
            return
        end
        core.select_current_pane(t.tab_id)
    end)
end

local fix_coord = function(c, max, limit)
    if c < 0 then
        return 0
    end

    if c + max >= limit - 1 then
        return limit - max - 2
    end

    return c
end

--- Shows all the floats
M.show_floats = function(group)
    local g = group or 'default'
    local floatings = vim.tbl_filter(function(t) return funcs.is_float(t) and t.group == g end, core.get_terminals())
    table.sort(floatings, function(a, b) return a.last_access < b.last_access end)
    for _, f in ipairs(floatings) do
        restore_float(f)
    end
    vim.fn.timer_start(1, function()
        EV.trigger_event('FloatsVisible')
    end)
    core.update_titles()
end

--- Opens a new float
--- @param group string The group in which to open a float
--- @param opts table the options of the new window (@ses vim.api.nvim_open_win)
--- @param to_restore terminals The float terminal to restore (optional)
M.open_float = function(group, opts, to_restore)
    current_group = group or funcs.current_float_group()
    if #funcs.get_all_floats(group, core.get_terminals()) > 0 and funcs.are_floats_hidden(group, core.get_terminals()) then
        M.show_floats(group)
    end
    local buf = vim.api.nvim_create_buf(true, false)
    local factor = 4
    local w = (vim.o.columns - factor) / 2
    local h = (vim.o.lines - factor) / 2
    local x = (vim.o.columns - w) / 2
    local y = (vim.o.lines - h) / 2
    local _opts = {
        width = math.floor(w), height = math.floor(h), col = math.floor(x), row = math.floor(y),
        focusable = true, zindex = 1, border = 'rounded', title = '...', relative = 'editor', style = 'minimal'
    }
    for k, v in pairs(opts or {}) do
        _opts[k] = v
    end
    vim.api.nvim_open_win(buf, true, _opts)
    vim.fn.timer_start(1, function()
        local opened = core.term_by_buf_id(buf)
        EV.trigger_event('FloatOpened', {opened})
        if to_restore ~= nil then
            opened.azul_placeholders = to_restore.azul_placeholders or {}
            opened.overriden_title = to_restore.overriden_title
        end
        core.update_titles()
    end)
end

--- Hides all the floats
--- 
--- @return nil
M.hide_floats = function()
    local floats = funcs.get_visible_floatings(core.get_terminals())
    for _, float in ipairs(floats) do
        close_float(float)
    end
    if #floats > 0 then
        EV.trigger_event('FloatHidden')
    end
    vim.fn.timer_start(1, function()
        core.update_titles()
    end)
end

--- Toggles the visibility of the floating windows
M.toggle_floats = function(group)
    if funcs.are_floats_hidden(group, core.get_terminals()) then
        M.show_floats(group)
    else
        M.hide_floats()
    end
    vim.fn.timer_start(1, function()
        core.enter_mode('t')
    end)
end

M.move_current_float = function(dir, inc)
    local buf = vim.fn.bufnr()
    local t = funcs.find(function(t) return funcs.get_real_buffer(t) == buf end, core.get_terminals())
    local conf = vim.api.nvim_win_get_config(0)
    if conf.relative == "" then return end
    local row, col = conf["row"], conf["col"]
    if type(row) ~= "number" then
        row = row[false]
    end
    if type(col) ~= 'number' then
        col = col[false]
    end
    local _inc = inc or 1

	if dir == "down" and (row + conf.height) < vim.o.lines then
		row = row + _inc
	elseif dir == "up" and row > 0 then
		row = row - _inc
	elseif dir == "left" and col > 0 then
		col = col - _inc
	elseif dir == "right" and (col+conf.width) < vim.o.columns then
		col = col + _inc
	end

    row = fix_coord(row, conf.height, vim.o.lines - 1)
    col = fix_coord(col, conf.width, vim.o.columns)

    conf["row"], conf["col"] = row, col
    vim.api.nvim_win_set_config(0, conf)
    if t ~= nil then
        t.win_config = conf
    end
    EV.trigger_event('FloatMoved', {t})
end

M.position_current_float = function(where)
    local conf = vim.api.nvim_win_get_config(0)
    local t = core.get_current_terminal()
    if not funcs.is_float(t) then
        EV.error("You can only position a floating window", nil)
    end

    if where == "top" then
        conf.row = 0
    elseif where == "end" then
        conf.col = fix_coord(vim.o.columns - conf.width, conf.width, vim.o.columns)
    elseif where == "bottom" then
        conf.row = fix_coord(vim.o.lines - conf.height, conf.height, vim.o.lines - 1)
    elseif where == "start" then
        conf.col = 0
    end
    vim.api.nvim_win_set_config(0, conf)
    core.refresh_win_config(t)
    EV.trigger_event('FloatMoved', {t})
end

M.rename_floating_pane = function(pane)
    if pane == nil then
        return
    end
    if not funcs.is_float(pane) then
        EV.error('You can only rename floating panes')
    end
    local def = funcs.get_float_title(pane)
    core.user_input({propmt = "Pane new name: ", default = def}, function(result)
        if result == '' then
            pane.overriden_title = nil
            TABS.del_var(core.get_global_tab_id(), 'azul_tab_title_overriden')
        elseif result ~= nil then
            pane.azul_placeholders = nil
            pane.overriden_title = result
        end
        core.update_titles()
    end, true)
end

M.rename_current_pane = function()
    local buf = vim.fn.bufnr()
    M.rename_floating_pane(funcs.find(function(t) return funcs.get_real_buffer(t) == buf end, core.get_terminals()))
end

--- Opens a new float
--- @param group string The group in which to open a float
--- @param force boolean If true, then always ask for the remote connection, even if the AZUL_REMOTE_CONNECTION var is set
--- @param opts table the options of the new window (@ses vim.api.nvim_open_win)
--- @param to_restore terminals The float terminal to restore (optional)
M.open_float_remote = function(group, force, opts, to_restore)
    core.do_open_remote(force, function()
        M.open_float(group, opts, to_restore)
    end)
end

M.toggle_fullscreen = function(t)
    if not funcs.is_float(t) then
        return
    end

    -- local config = t.
end

EV.on({'PaneClosed', 'PaneChanged'}, rebuild_zindex_floats)

EV.on('TerminalAdded', function(args)
    args[1].group = current_group
    local added = core.refresh_buf(args[1].buf)
    local crt = core.get_current_terminal()
    if crt == nil or added == nil or funcs.is_float(added) or funcs.are_floats_hidden(crt.group, core.get_terminals()) or not funcs.is_float(crt) then
        return
    end
    M.hide_floats()
end)

return M
