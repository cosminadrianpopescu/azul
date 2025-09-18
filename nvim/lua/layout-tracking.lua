local azul = require('core')
local funcs = require('functions')

local M = {}
local L = {}
local current_in_saved_layout = nil
local can_save_layout = true

local term_by_azul_win_id = function(id)
    return funcs.find(function(t) return t.azul_win_id == id end, azul.get_terminals())
end

local term_by_panel_id = function(id)
    return funcs.find(function(t) return t.panel_id == id end, azul.get_terminals())
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
            M.send_to_buf(t.buf, _cmd, true)
        end)
    end
end

L.restore_remotes = function()
    local remotes = vim.tbl_filter(function(t) return t.remote_command ~= nil end, azul.get_terminals())
    for _, r in ipairs(remotes) do
        vim.fn.jobstop(r.term_id)
    end
    azul.stop_updating_titles()
    azul.update_titles()
    can_save_layout = true
    azul.trigger_event("LayoutRestored")
    if current_in_saved_layout then
        if current_in_saved_layout.tab_page ~= nil then
            azul.select_tab(current_in_saved_layout.tab_page)
        end
        local t = term_by_azul_win_id(current_in_saved_layout.azul_win_id)
        if not azul.is_float(t) then
            azul.hide_floats()
        end
        vim.defer_fn(function()
            azul.select_pane(t.buf)
            current_in_saved_layout = nil
        end, 1)
    end
    M.enter_mode('t')
end

L.restore_ids = function(title_placeholders, title_overrides)
    azul.set_global_panel_id(0)
    azul.set_global_tab_id(0)
    for _, t in ipairs(azul.get_terminals()) do
        if t.panel_id > panel_id then
            azul.set_global_panel_id(t.panel_id)
        end
        if t.tab_id > tab_id then
            azul.set_global_tab_id(t.tab_id)
        end
    end
    azul.set_global_tab_id(azul.get_global_tab_id() + 1)
    azul.set_global_tab_id(azul.get_global_tab_id() + 1)
    for i, p in ipairs(title_placeholders or {}) do
        vim.api.nvim_tabpage_set_var(vim.api.nvim_list_tabpages()[i], 'azul_placeholders', p)
    end
    for i, o in ipairs(title_overrides or {}) do
        if o ~= '' then
            vim.api.nvim_tabpage_set_var(vim.api.nvim_list_tabpages()[i], 'azul_tab_title_overriden', o)
        end
    end

    vim.fn.timer_start(1, L.restore_remotes)
end

L.restore_floats = function(histories, idx, panel_id_wait, timeout)
    if timeout > 100 then
        azul.stop_updating_titles()
        azul.error("Trying to restore a session. Waiting for " .. panel_id_wait, nil)
    end

    if panel_id_wait ~= nil then
        local t = term_by_panel_id(panel_id_wait)
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

    azul.set_global_panel_id(f.panel_id)
    azul.open_float(f.group, f.win_config, f)

    L.restore_floats(histories, idx + 1, f.panel_id, 0)
end

L.restore_tab_history = function(histories, i, j, panel_id_wait, timeout)
    if timeout > 100 then
        azul.stop_updating_titles()
        azul.error("Timeout trying to restore the session. Waiting for " .. panel_id_wait, i .. ", " .. j)
    end

    if panel_id_wait ~= nil then
        local t = term_by_panel_id(panel_id_wait)
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
        azul.set_global_panel_id(h.to)
        azul.set_global_tab_id(h.tab_id)
        local buf = nil
        if j == 1 and i == 1 then
            buf = vim.fn.bufnr('%')
            vim.api.nvim_tabpage_get_var(0, 'azul_tab_id')
            vim.api.nvim_tabpage_set_var(0, 'azul_tab_id', tab_id)
        end
        azul.open(true, buf)
        vim.fn.timer_start(10, function()
            L.restore_tab_history(histories, i, j + 1, h.to, 0)
        end)
        return
    end

    if h.operation == "split" then
        azul.set_global_panel_id(h.to)
        local t = term_by_panel_id(h.from)
        if t == nil then
            azul.error("Error found loading the layout file", h)
        end
        azul.select_pane(t.buf)
        azul.split(h.params[1])
        vim.fn.timer_start(10, function()
            L.restore_tab_history(histories, i, j + 1, h.to, 0)
        end)
        return
    end

    if h.operation == "close" then
        local t = term_by_panel_id(h.from)
        if t == nil then
            azul.error("Error found loading the layout file", h)
        end
        vim.fn.chanclose(t.term_id)
        vim.fn.timer_start(10, function()
            azul.restore_tab_history(histories, i, j + 1, nil, 0)
        end)
        return
    end

    if h.operation == "resize" then
        local t = term_by_panel_id(h.from)
        if t == nil then
            azul.error("Error found loading the layout file", h)
        end
        azul.select_pane(t.buf)
        azul.resize(h.params[1])
        vim.fn.timer_start(10, function()
            L.restore_tab_history(histories, i, j + 1, nil, 0)
        end)
        return
    end

    if h.operation == "rotate_panel" then
        local t = term_by_panel_id(h.from)
        if t == nil then
            azul.error("Error found loading the layout file", h)
        end
        azul.select_pane(t.buf)
        azul.rotate_panel()
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
    if #azul.get_terminals() > 1 then
        azul.error("You have already several windows opened. You can only call this function when you have no floats and only one tab opened", nil)
        return
    end
    local f = io.open(where, "r")
    if f == nil then
        M.error("Could not open " .. where, nil)
    end
    local h = funcs.deserialize(f:read("*a"))
    h.callback = callback
    azul.start_updating_titles()
    funcs.safe_del_tab_var(0, 'azul_placeholders')
    local t = azul.get_current_terminal()
    local old_buf = t.buf
    t.buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(t.win_id, t.buf)
    vim.fn.jobstop(t.term_id)
    vim.api.nvim_buf_delete(old_buf, {force = true})
    azul.do_remove_term_buf(t.buf)
    azul.reset_history()
    if h.geometry ~= nil then
        vim.o.columns = h.geometry.columns
        vim.o.lines = h.geometry.lines
    end
    current_in_saved_layout = h.current
    L.restore_tab_history(h, 1, 1, nil, 0)
    f:close()
end

azul.persistent_on('ExitAzul', function()
    can_save_layout = false
end)

return M
