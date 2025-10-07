local core = require('core')
local funcs = require('functions')
local FILES = require('files')
local F = require('floats')
local H = require('history')
local EV = require('events')
local TABS = require('tab_vars')
local options = require('options')

local M = {}
local L = {}
local current_in_saved_layout = nil
local can_save_layout = true

local term_by_azul_win_id = function(id)
    return funcs.find(function(t) return t.azul_win_id == id end, core.get_terminals())
end

local histories_by_tab_id = function(tab_id, history)
    return vim.tbl_filter(function(h) return h.tab_id == tab_id end, history)
end

local get_custom_values = function()
    local result = {}
    for _, t in ipairs(core.get_terminals()) do
        result[t.panel_id .. ""] = {
            azul_win_id = t.azul_win_id,
            azul_cmd = t.azul_cmd or nil,
            remote_command = t.remote_command
        }
    end

    return result
end

local post_restored = function(t, customs, callback)
    local c = customs[t.panel_id .. ""]
    if c == nil then
        return
    end
    t.azul_win_id = c.azul_win_id
    if c.azul_cmd ~= nil then
        t.azul_cmd = c.azul_cmd
    end
    if c.remote_command ~= nil then
        t.remote_command = c.remote_command
    end

    if callback ~= nil then
        callback(t, t.azul_win_id)
    end

    if t.azul_cmd ~= nil and t.remote_command == nil then
        local _cmd = t.azul_cmd .. '<cr>'
        vim.fn.timer_start(1000, function()
            core.send_to_buf(t.buf, _cmd, true)
        end)
    end
end

local session_extension = '.azul'

local sessions_folder = function()
    local result = options.autosave_location or (FILES.config_dir .. '/sessions')
    if vim.fn.isdirectory(result) == 0 then
        vim.fn.mkdir(result)
    end
    return result
end

local session_save_name = function()
    return sessions_folder() .. '/' .. os.getenv('AZUL_SESSION') .. session_extension
end

local session_exists = function()
    return FILES.exists(session_save_name())
end

L.restore_remotes = function()
    local remotes = vim.tbl_filter(function(t) return t.remote_command ~= nil end, core.get_terminals())
    for _, r in ipairs(remotes) do
        vim.fn.jobstop(r.term_id)
    end
    core.stop_updating_titles()
    core.update_titles()
    can_save_layout = true
    EV.trigger_event("LayoutRestored")
    if current_in_saved_layout then
        if current_in_saved_layout.tab_page ~= nil then
            core.select_tab(current_in_saved_layout.tab_page)
        end
        local t = term_by_azul_win_id(current_in_saved_layout.azul_win_id)
        if not funcs.is_float(t) then
            F.hide_floats()
        end
        vim.defer_fn(function()
            core.select_pane(t.buf)
            current_in_saved_layout = nil
        end, 1)
    end
    core.enter_mode('t')
end

L.restore_ids = function(title_placeholders, title_overrides)
    core.set_global_panel_id(0)
    core.set_global_tab_id(0)
    core.set_global_azul_win_id(0)
    for _, t in ipairs(core.get_terminals()) do
        if t.panel_id > core.get_global_panel_id() then
            core.set_global_panel_id(t.panel_id)
        end
        if t.tab_id > core.get_global_tab_id() then
            core.set_global_tab_id(t.tab_id)
        end
        if t.azul_win_id ~= nil and type(t.azul_win_id) == 'number' and t.azul_win_id > core.get_global_azul_win_id() then
            core.set_global_azul_win_id(t.azul_win_id)
        end
    end
    core.set_global_panel_id(core.get_global_panel_id() + 1)
    core.set_global_tab_id(core.get_global_tab_id() + 1)
    core.set_global_azul_win_id(core.get_global_azul_win_id() + 1)
    for i, p in ipairs(title_placeholders or {}) do
        TABS.set_var(vim.api.nvim_list_tabpages()[i], 'azul_placeholders', p)
    end
    for i, o in ipairs(title_overrides or {}) do
        if o ~= '' then
            TABS.set_var(vim.api.nvim_list_tabpages()[i], 'azul_tab_title_overriden', o)
        end
    end

    vim.fn.timer_start(1, L.restore_remotes)
end

L.restore_floats = function(histories, idx, panel_id_wait, timeout)
    if timeout > 100 then
        core.stop_updating_titles()
        EV.error("Trying to restore a session. Waiting for " .. panel_id_wait, nil)
        return
    end

    if panel_id_wait ~= nil then
        local t = funcs.term_by_panel_id(panel_id_wait, core.get_terminals())
        if t == nil then
            vim.fn.timer_start(10, function()
                L.restore_floats(histories, idx, panel_id_wait, timeout + 1)
            end)
            return
        end
        post_restored(t, histories.customs, histories.callback)
    end

    if idx > #histories.floats then
        L.restore_ids(histories.azul_placeholders or histories.azul_title_placeholders, histories.title_overrides)
        return
    end

    local f = histories.floats[idx]

    core.set_global_panel_id(f.panel_id)
    F.open_float(f.group, f.win_config, f)

    L.restore_floats(histories, idx + 1, f.panel_id, 0)
end

L.restore_tab_history = function(histories, i, j, panel_id_wait, timeout)
    if timeout > 100 then
        core.stop_updating_titles()
        EV.error("Timeout trying to restore the session. Waiting for " .. panel_id_wait, i .. ", " .. j)
        return
    end

    if panel_id_wait ~= nil then
        local t = funcs.term_by_panel_id(panel_id_wait, core.get_terminals())
        if t == nil then
            vim.fn.timer_start(10, function()
                L.restore_tab_history(histories, i, j, panel_id_wait, timeout + 1)
            end)
            return
        end
        post_restored(t, histories.customs, histories.callback)
    end

    if (i > #histories.history) then
        L.restore_floats(histories, 1, nil, 0)
        return
    end

    if (j > #histories.history[i]) then
        L.restore_tab_history(histories, i + 1, 1, nil, 0)
        return
    end

    local h = histories.history[i][j]

    if h.operation == "create" then
        core.set_global_panel_id(h.to)
        core.set_global_tab_id(h.tab_id)
        local buf = nil
        if j == 1 and i == 1 then
            buf = vim.fn.bufnr('%')
            TABS.set_var(0, 'azul_tab_id', core.get_global_tab_id())
        end
        core.open(buf)
        vim.fn.timer_start(10, function()
            L.restore_tab_history(histories, i, j + 1, h.to, 0)
        end)
        return
    end

    if h.operation == "split" then
        core.set_global_panel_id(h.to)
        local t = funcs.term_by_panel_id(h.from, core.get_terminals())
        if t == nil then
            EV.error("Error found loading the layout file", h)
            return
        end
        core.select_pane(t.buf)
        core.split(h.params[1])
        vim.fn.timer_start(10, function()
            L.restore_tab_history(histories, i, j + 1, h.to, 0)
        end)
        return
    end

    if h.operation == "close" then
        local t = funcs.term_by_panel_id(h.from, core.get_terminals())
        if t == nil then
            EV.error("Error found loading the layout file", h)
            return
        end
        vim.fn.chanclose(t.term_id)
        vim.fn.timer_start(10, function()
            L.restore_tab_history(histories, i, j + 1, nil, 0)
        end)
        return
    end

    if h.operation == "resize" then
        local t = funcs.term_by_panel_id(h.from, core.get_terminals())
        if t == nil then
            EV.error("Error found loading the layout file", h)
            return
        end
        core.select_pane(t.buf)
        core.resize(h.params[1])
        vim.fn.timer_start(10, function()
            L.restore_tab_history(histories, i, j + 1, nil, 0)
        end)
        return
    end

    if h.operation == "rotate_panel" then
        local t = funcs.term_by_panel_id(h.from, core.get_terminals())
        if t == nil then
            EV.error("Error found loading the layout file", h)
            return
        end
        core.select_pane(t.buf)
        core.rotate_panel()
        vim.fn.timer_start(10, function()
            L.restore_tab_history(histories, i, j + 1, nil, 0)
        end)
        return
    end
end

--- Restores a saved layout
---
--- @param where string The saved file location
--- @param callback function(t) callback called after each terminal is restored. 
---                             The t is the just opened terminal
M.restore_layout = function(where, callback)
    if #core.get_terminals() > 1 then
        EV.error("You have already several windows opened. You can only call this function when you have no floats and only one tab opened", nil)
        return
    end
    local f = io.open(where, "r")
    if f == nil then
        EV.error("Could not open " .. where, nil)
        return
    end
    local h = funcs.deserialize(f:read("*a"))
    h.callback = callback
    core.stop_updating_titles()
    TABS.del_var(0, 'azul_placeholders')
    local t = core.get_current_terminal()
    local old_buf = t.buf
    t.buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(t.win_id, t.buf)
    vim.fn.jobstop(t.term_id)
    vim.api.nvim_buf_delete(old_buf, {force = true})
    core.do_remove_term_buf(t.buf)
    H.reset_history()
    if h.geometry ~= nil then
        vim.o.columns = h.geometry.columns
        vim.o.lines = h.geometry.lines
    end
    EV.trigger_event('LayoutRestoringStarted')
    current_in_saved_layout = h.current
    L.restore_tab_history(h, 1, 1, nil, 0)
    f:close()
end

EV.persistent_on('ExitAzul', function()
    can_save_layout = false
end)

M.save_layout = function(where, auto)
    for _, t in ipairs(core.get_terminals()) do
        core.refresh_tab_page(t)
    end
    local history_to_save = {}
    local placeholders = {}
    local title_overrides = {}
    for _, id in ipairs(vim.api.nvim_list_tabpages()) do
        table.insert(history_to_save, histories_by_tab_id(TABS.get_var(id, 'azul_tab_id'), H.get_history()))
        table.insert(placeholders, TABS.get_var(id, 'azul_placeholders') or {})
        table.insert(title_overrides, TABS.get_var(id, 'azul_tab_title_overriden') or '')
    end
    local t = core.get_current_terminal()
    local current = nil
    if t ~= nil then
        current = {
            tab_id = t.tab_id,
            azul_win_id = t.azul_win_id,
            tab_page = t.tab_page,
            pane_id = t.panel_id,
        }
    end
    FILES.write_file(where, vim.inspect({
        floats = vim.tbl_filter(function(x) return funcs.is_float(x) end, core.get_terminals()),
        history = history_to_save,
        customs = get_custom_values(),
        azul_placeholders = placeholders,
        title_overrides = title_overrides,
        current = current,
        geometry = {
            columns = vim.o.columns,
            lines = vim.o.lines
        }
    }))
    EV.trigger_event("LayoutSaved", {where, auto})
end

M.auto_save_layout = function()
    if not funcs.is_autosave() or not can_save_layout or funcs.is_marionette() then
        return
    end
    M.save_layout(session_save_name(), true)
end

M.auto_restore_layout = function()
    local callback = nil
    if FILES.exists(session_save_name() .. '.lua') then
        callback = FILES.load_as_module(os.getenv('AZUL_SESSION') .. session_extension, sessions_folder())
    end
    core.open()
    vim.defer_fn(function()
        M.restore_layout(session_save_name(), callback)
    end, 1)
end

M.start = function()
    if funcs.is_marionette() then
        core.open()
        return
    end

    if funcs.is_autosave() and session_exists() then
        can_save_layout = false
        core.stop_updating_titles()
        M.auto_restore_layout()
        return
    end

    if funcs.is_handling_remote() and os.getenv('AZUL_START_REMOTE') == '1' then
        core.open_remote()
    else
        core.open()
    end
end

EV.persistent_on('ExitAzul', function()
    can_save_layout = false
    if funcs.is_autosave() and session_exists() and #core.get_terminals() == 0 then
        os.remove(session_save_name())
    end
end)

local do_autosave = function()
    vim.defer_fn(function()
        M.auto_save_layout()
    end, 1)
end

EV.persistent_on({
    'CommandSet', 'WinIdSet', 'TabTitleChanged', 'HistoryChanged',
    'FloatOpened', 'PaneClosed', 'FloatTitleChanged', 'UndoFinished',
}, do_autosave)

EV.persistent_on({'FloatMoved', 'PaneChanged', 'PaneResized'}, function()
    if options.autosave ~= 'always' then
        return
    end
    do_autosave()
end)

EV.persistent_on({'AzulStarted', 'LayoutRestored'}, function()
    if not can_save_layout then
        return
    end
    vim.fn.timer_start(200, function()
        core.start_updating_titles()
        core.update_titles()
    end)
end)

return M
