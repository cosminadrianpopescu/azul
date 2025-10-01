local cmd = vim.api.nvim_create_autocmd
local funcs = require('functions')
local FILES = require('files')
local H = require('history')
local TABS = require('tab_vars')
local EV = require('events')
local options = require('options')

local M = {}

local is_suspended = false
local is_user_editing = false
local is_started = false

local updating_titles = true
local azul_started = false
local last_access = 0
local remote_command = nil
local to_save_remote_command = nil
local dead_terminal = nil

--- @class terminals
--- @field is_current boolean If true, it means that this is the current terminal
--- @field cwd string The current working dir
--- @field buf number The corresponding nvim buffer number
--- @field editing_buf number If the scroll back tab is being edited in the $EDITOR, this is the editor buf if
--- @field tab_page number The corresponding neovim tab
--- @field win_id number The current neovim window id
--- @field term_id number The current neovim channel id
--- @field panel_id number The panel assigned number (to be used for session restore)
--- @field tab_id number The tab assigned number (to be used for session restore)
--- @field azul_win_id string The custom azul windows id
--- @field win_config table The current neovim window config
--- @field current_selected_pane boolean If a tab contains more than one embedded pane, this will be true for the currently selected pane
--- @field remote_command string The terminal's remote connection
--- @field group string The float current group, if the terminal is a float
local terminals = {}
local tab_id = 0
local azul_win_id = 0
local chan_buffers = {}
local panel_id = 0

local loggers = {}

local mode = nil
local mode_mappings = {
}
local workflow = 'azul'
local mod = nil
local global_last_status = nil
local quit_on_last = true

local L = {}

local current_win_has_no_pane = function()
    local t = M.term_by_buf_id(vim.fn.bufnr('%'))
    if t == nil then
        return vim.b.terminal_job_id == nil
    end
    return vim.b.terminal_job_id == nil and M.remote_state(t) ~= 'disconnected'
end

local do_exit = function()
    M.suspend()
    local channels = vim.tbl_filter(function(c) return c.mode == 'terminal' end, vim.api.nvim_list_chans())
    for _, c in ipairs(channels) do
        vim.fn.jobstop(c.id)
    end
    EV.trigger_event('ExitAzul')
end

M.do_remove_term_buf = function(buf)
    terminals = vim.tbl_filter(function(t) return t.buf ~= buf end, terminals)
end

local remove_term_buf = function(buf)
    M.do_remove_term_buf(buf)
    if quit_on_last and (#terminals == 0 or #vim.tbl_filter(function(t) return funcs.is_float(t) == false end, terminals) == 0) then
        do_exit()
        vim.api.nvim_command('quit!')
    end
end

M.debug = function()
    -- print(vim.inspect(vim.tbl_filter(function(t) return funcs.is_float(t) end, M.get_terminals())))
    -- print(vim.inspect(vim.tbl_map(function(m) return m.ls end, vim.tbl_filter(function(x) return x.m == ev end, mode_mappings))))
    -- print("OPTIONS ARE " .. vim.inspect(options))
    -- print("LOGGERS ARE " .. vim.inspect(loggers))
    -- print("EV IS " .. vim.inspect(ev))
    -- print("WIN IS " .. vim.fn.winnr())
    -- print("WIN ID IS " .. vim.fn.win_getid(vim.fn.winnr()))
    -- print("TITLE IS ALREADY" .. vim.b.term_title)
    -- print("JOB ID IS " .. vim.b.terminal_job_id)
    -- print("MAPPINGS ARE" .. vim.inspect(mode_mappings))
    -- print("MAPPINGS ARE" .. vim.inspect(vim.tbl_filter(function(m) return m.m == 'P' end, mode_mappings)))
    -- print("MODE IS" .. mode)
    -- print("HISTORY IS " .. vim.inspect(history))
end

M.refresh_tab_page = function(t)
    if funcs.is_float(t) then
        return
    end
    t.tab_page = vim.api.nvim_tabpage_get_number(vim.api.nvim_win_get_tabpage(t.win_id))
    t.vim_tab_id = vim.api.nvim_list_tabpages()[t.tab_page]
end

M.refresh_win_config = function(t)
    local old_config = t.win_config
    t.win_config = vim.api.nvim_win_get_config(t.win_id)
    M.refresh_tab_page(t)
    if t.win_config['height'] == nil then
        t.win_config.height = vim.api.nvim_win_get_height(t.win_id)
    end
    if t.win_config['width'] == nil then
        t.win_config.width = vim.api.nvim_win_get_width(t.win_id)
    end
    if old_config == nil or old_config.col ~= t.win_config.col or old_config.height ~= t.win_config.height
        or old_config.row ~= t.win_config.row or old_config.width ~= t.win_config.width then
        vim.fn.timer_start(1, function()
            EV.trigger_event('WinConfigChanged', {t})
        end)
    end
end

M.refresh_buf = function(buf, with_win_id)
    local t = funcs.find(function(t) return funcs.get_real_buffer(t) == buf end, terminals)
    if t == nil then
        return nil
    end
    if with_win_id == nil or with_win_id == true then
        t.win_id = vim.fn.win_getid(vim.fn.winnr())
        M.refresh_win_config(t)
    end
    return t
end

M.select_current_pane = function(tab_id)
    local t = funcs.find(function(t) return t.current_selected_pane end, L.terms_by_tab_id(tab_id))
    if t == nil then
        return
    end
    vim.api.nvim_command(vim.fn.bufwinnr(t.buf) .. "wincmd w")
end

local set_current_panel = function(tab_id)
    for _, t in ipairs(L.terms_by_tab_id(tab_id)) do
        t.current_selected_pane = false
    end

    local t = M.get_current_terminal()
    if t == nil then
        return
    end
    t.current_selected_pane = true
end

--- Returns the current selected terminal
---
---@return terminals|nil
M.get_current_terminal = function()
    return funcs.find(function(t) return t.is_current end, terminals)
end

local OnEnter = function(ev)
    if is_suspended then
        return
    end
    if dead_terminal ~= nil then
        dead_terminal.callback({buf = dead_terminal.term.buf})
        dead_terminal = nil
    end
    local crt = M.refresh_buf(ev.buf)
    if crt == nil then
        return
    end

    -- if funcs.is_float(crt) == false then
    --     M.hide_floats()
    -- end
    crt.last_access = last_access
    last_access = last_access + 1

    local is_current_terminal = (M.get_current_terminal() and M.get_current_terminal().buf) or nil
    local old = funcs.find(function(t) return t.is_current end, M.get_terminals())

    for _, t in ipairs(terminals) do
        vim.api.nvim_buf_set_option(t.buf, 'buflisted', t.win_id == crt.win_id)
        t.is_current = funcs.get_real_buffer(t) == ev.buf
        if t.is_current and funcs.get_real_buffer(t) ~= is_current_terminal then
            EV.trigger_event('PaneChanged', {t, old})
        end
        if t.is_current and options.auto_start_logging and not L.is_logging_started(t.buf) then
            M.start_logging(os.tmpname())
        end
    end
    if not azul_started then
        azul_started = true
        EV.trigger_event('AzulStarted')
    end
end

local on_chan_input = function(callback, which, chan_id, data)
    local t = funcs.find(function(x) return x.term_id == chan_id end, terminals)
    if t == nil then
        return
    end

    if chan_buffers[t.term_id] == nil then
        chan_buffers[t.term_id] = {out = "", err = ""}
    end

    local b = chan_buffers[t.term_id]

    for _, s in ipairs(data) do
        for c in s:gmatch(".") do
            if c == "\r" or c == "\n" then
                callback(which, b[which], t)
                b[which] = ''
            else
                b[which] = b[which] .. c
            end
        end
    end
end

--- Opens a new terminal in the current window
---
---@param start_edit boolean If true, then start editing automatically (default true)
---@param buf number The buffer in which to open the terminal
---@param callback function If set, then the callback will be called everytime for a new line in the terminal
M.open = function(start_edit, buf, callback)
    if M.term_by_buf_id(vim.fn.bufnr('%')) ~= nil and buf == nil then
        L.open_params = {start_edit, buf, callback}
        vim.api.nvim_command('$tabnew')
        return
    end
    if L.open_params ~= nil then
        start_edit = L.open_params[1]
        buf = L.open_params[2]
        callback = L.open_params[3]
        L.open_params = nil
    end
    local environment = require('environment').get_environment()
    environment['VIM'] = ''
    environment['VIMRUNTIME'] = ''
    local opts = {
        term = true,
        cdw = vim.fn.getcwd(),
        env = environment,
    }

    if callback ~= nil then
        opts['on_stdout'] = function(chan, data, _)
            on_chan_input(callback, 'out', chan, data)
        end
        opts['on_stderr'] = function(chan, data, _)
            on_chan_input(callback, 'err', chan, data)
        end
    end

    local do_open = function()
        local cmd = (remote_command == nil and {vim.o.shell}) or remote_command
        if not is_started and remote_command == nil then
            local safe, _ = pcall(function()
                vim.fn.jobstart(cmd, opts)
            end)
            if not safe then
                FILES.write_file(os.getenv('AZUL_RUN_DIR') .. '/' .. os.getenv('AZUL_SESSION') .. '-failed', '')
                vim.api.nvim_command('quit!')
            end
        else
            vim.fn.jobstart(cmd, opts)
        end
    end
    to_save_remote_command = remote_command
    if buf == nil then
        do_open()
    else
        vim.api.nvim_buf_call(buf, do_open)
    end
    remote_command = nil
    if type(start_edit) == 'boolean' and start_edit == false then
        return
    end
end

local OnTermClose = function(ev)
    if is_suspended then
        return
    end
    local t = funcs.find(function(t) return t.buf == ev.buf end, terminals)
    if t == nil then
        return
    end
    if t.remote_command ~= nil then
        EV.trigger_event('RemoteDisconnected', {t})
        vim.fn.timer_start(1, function()
            M.refresh_buf(t.buf, false)
        end)
        return
    end
    H.add_to_history(M.term_by_buf_id(ev.buf), "close", nil, t.tab_id)
    remove_term_buf(ev.buf)
    if #terminals == 0 then
        return
    end
    if t ~= nil then
        if funcs.find(function(t2) return t2.win_id == t.win_id end, terminals) == nil then
            funcs.safe_close_window(t.win_id)
        else
            vim.api.nvim_command('bnext')
        end
    end
    vim.api.nvim_buf_delete(ev.buf, {force = true})
    EV.trigger_event("PaneClosed", {t})
    vim.fn.timer_start(1, function()
        ev.buf = vim.fn.bufnr()
        OnEnter(ev)
    end)
end

local anounce_passthrough = function()
    local f = funcs.session_child_file(true)
    if not FILES.exists(f) then
        return
    end
    FILES.write_file(f, "true")
end

local recall_passthrough = function()
    local f = funcs.session_child_file(true)
    if not FILES.exists(f) then
        return
    end
    FILES.write_file(f, "")
end

--- Enters a custom mode. Use this function for changing custom modes
---@param new_mode 'p'|'r'|'s'|'m'|'T'|'n'|'t'|'v'|'P'|'M'|'a'
M.enter_mode = function(new_mode)
    local old_mode = mode
    if mode == 'P' then
        if options.hide_in_passthrough then
            vim.o.laststatus = global_last_status
        end
        recall_passthrough()
        L.passthrough_escape = nil
    end
    mode = new_mode
    if mode == 'P' then
        vim.fn.timer_start(1, function()
            if options.hide_in_passthrough then
                global_last_status = vim.o.laststatus
                vim.o.laststatus = 0
            end
        end)
        anounce_passthrough()
    end
    if old_mode ~= new_mode then
        EV.trigger_event('ModeChanged', {old_mode, new_mode})
    end
end

cmd({'UIEnter'}, {
    pattern = "*", callback = function()
        if not azul_started then
            return
        end
        EV.trigger_event('AzulConnected')
    end
})

cmd({'TabNew', 'VimEnter'}, {
    pattern = "*", callback = function()
        TABS.set_var(0, 'azul_tab_id', tab_id)
        tab_id = tab_id + 1
    end
})

local get_tab_title = function(t)
    local overriden_title = TABS.get_var(t, 'azul_tab_title_overriden')
    return overriden_title or options.tab_title
end

local get_default_placeholders = function(t)
    local azul_win_id = (t and t.azul_win_id) or ''
    local azul_cmd = (t and t.azul_cmd) or ''
    local term_title = ''
    if t ~= nil then
        term_title = funcs.safe_get_buf_var(t.buf, 'term_title') or ''
    end

    if type(term_title) ~= 'string' then
        term_title = term_title[1][1]
    end

    return {
        term_title = term_title,
        azul_win_id = azul_win_id,
        azul_cmd = azul_cmd,
        azul_cmd_or_win_id = (azul_cmd ~= '' and azul_cmd ~= nil and azul_cmd) or azul_win_id,
    }
end

M.update_titles = function(callback)
    if updating_titles or not azul_started then
        return
    end

    local finished = function()
        updating_titles = false
        if callback ~= nil then
            callback()
        end
    end
    updating_titles = true
    local floats = funcs.get_visible_floatings(terminals)
    local titles_to_update = #vim.api.nvim_list_tabpages() + #floats
    local titles_updated = 0
    local current_tab_page = vim.fn.tabpagenr()
    for i, t in ipairs(vim.api.nvim_list_tabpages()) do
        local tab_placeholders = TABS.get_var(t, 'azul_placeholders')
        local current_pane = funcs.find(function(t) return t.tab_page == i and t.current_selected_pane end, M.get_terminals())
        local default_placeholders = get_default_placeholders(current_pane)
        local placeholders = vim.tbl_extend(
            'keep', {
                tab_n = i, is_current = (i == current_tab_page and '*') or '',
            },
            default_placeholders, tab_placeholders or {}
        )
        M.parse_custom_title(
            get_tab_title(t),
            placeholders,
            'for tab ' .. i,
            function(title, placeholders)
                titles_updated = titles_updated + 1
                if titles_updated >= titles_to_update then
                    finished()
                end
                local trigger = false
                if TABS.get_var(t, 'azul_tab_title') ~= title then
                    trigger = true
                end
                TABS.set_var(t, 'azul_placeholders', placeholders)
                TABS.set_var(t, 'azul_tab_title', title)
                if trigger then
                    EV.trigger_event('TabTitleChanged', {t, title})
                end
            end
        )
    end

    for _, f in ipairs(floats) do
        local float_placeholders = f.azul_placeholders
        local default_placeholders = get_default_placeholders(f)
        local placeholders = vim.tbl_extend(
            'keep', default_placeholders, float_placeholders or {}
        )
        M.parse_custom_title(
            funcs.get_float_title(f),
            placeholders,
            'for pane with ' .. placeholders.term_title,
            function(title, placeholders)
                titles_updated = titles_updated + 1
                if titles_updated >= titles_to_update then
                    finished()
                end
                local trigger = false
                if f.win_config.title ~= title then
                    trigger = true
                end
                f.azul_placeholders = placeholders
                f.win_config.title = title
                if f.win_id ~= nil then
                    vim.api.nvim_win_set_config(f.win_id, f.win_config)
                end
                if trigger then
                    EV.trigger_event('FloatTitleChanged', {f})
                end
            end
        )
    end
end

cmd({"VimLeave"},{
    desc = "launch ExitAzul event",
    callback = do_exit,
})

cmd({'TabNew', 'TermClose', 'TabEnter'}, {
    pattern= '*', callback = function()
        vim.fn.timer_start(1, function()
            M.update_titles()
        end)
    end
})

cmd('TermOpen',{
    pattern = "*", callback = function(ev)
        if is_suspended or #vim.tbl_filter(function(x) return x.term_id == vim.b.terminal_job_id end, terminals) > 0 then
            return
        end
        local new_terminal = {
            is_current = false,
            buf = ev.buf,
            win_id = vim.fn.win_getid(vim.fn.winnr()),
            term_id = vim.b.terminal_job_id,
            tab_id = TABS.get_var(0, 'azul_tab_id'),
            panel_id = panel_id,
            cwd = vim.fn.getcwd(),
            azul_win_id = azul_win_id,
        }
        if to_save_remote_command ~= nil then
            new_terminal.remote_command = to_save_remote_command
        end
        table.insert(terminals, new_terminal)
        EV.trigger_event('TerminalAdded', {new_terminal})
        OnEnter(ev)
        local history = H.get_history()
        if #history > 0 and history[#history].to == -1 then
            history[#history].to = panel_id
        else
            local t = M.term_by_buf_id(ev.buf)
            if t and not funcs.is_float(t) then
                H.add_to_history(M.term_by_buf_id(ev.buf), "create", {}, t.tab_id)
            end
        end
        panel_id = panel_id + 1
        azul_win_id = azul_win_id + 1
    end
})

cmd({'TabClosed'}, {
    pattern = '*', callback = function(ev)
        local t = M.term_by_buf_id(ev.buf)
        if t == nil then
            return
        end
        vim.fn.jobstop(t.term_id)
        dead_terminal = {callback = OnTermClose, term = t}
    end
})

cmd('TermClose', {
    pattern = "*", callback = function(ev)
        OnTermClose(ev)
    end
})

cmd('TermEnter', {
    pattern = "*", callback = OnEnter
})

cmd({'FileType', 'BufEnter'}, {
    pattern = "*", callback = function()
        local was_user_editing = is_user_editing
        is_user_editing = vim.o.filetype == 'azul_prompt'
        if is_user_editing and not was_user_editing then
            EV.trigger_event('UserInputPrompt')
        end
    end
})

cmd({'TabEnter', 'WinResized', 'VimResized'}, {
    pattern = "*", callback = function()
        vim.fn.timer_start(1, function()
            vim.o.cmdheight = 0
        end)
    end
})

cmd({'TabLeave'}, {
    pattern = "*", callback = function()
        if is_suspended then
            return
        end
        TABS.set_var(0, 'current_buffer', vim.fn.bufnr())
    end
})

cmd({'WinNew', 'WinEnter'}, {
    pattern = "*", callback = function(ev)
        if is_suspended or is_user_editing then
            return
        end
        vim.fn.timer_start(1, function()
            ev.buf = vim.fn.bufnr('%')
            local buftype = vim.api.nvim_get_option_value('buftype', {buf = ev.buf})
            local filetype = vim.api.nvim_get_option_value('filetype', {buf = ev.buf})
            if current_win_has_no_pane() then
                M.open(false)
            end
            if ev.event == 'WinEnter' and (buftype == 'terminal' or filetype == 'AzulRemoteTerm') then
                OnEnter(ev)
            end
        end)
    end
})

cmd({'BufLeave', 'BufEnter'}, {
    pattern = {'*'}, callback = function(ev)
        local t = M.term_by_buf_id(ev.buf)
        if t == nil then
            return
        end
        if M.remote_state(t) == 'disconnected' then
            EV.trigger_event((ev.event == 'BufLeave' and 'LeaveDisconnectedPane') or 'EnterDisconnectedPane', {t})
        end
    end
})

cmd({'ModeChanged'}, {
    pattern = {'*'}, callback = function(ev)
        if is_suspended then
            return
        end
        local to = string.gsub(ev.match, '^[^:]+:(.*)', '%1'):sub(1, 1)
        local from = string.gsub(ev.match, '^([^:]+):.*', '%1'):sub(1, 1)
        if M.remote_state(M.get_current_terminal()) == 'disconnected' then
            -- Block insert or visual mode for a disconnected buffer
            if to == 'i' or to == 'v' then
                vim.fn.timer_start(1, function()
                    vim.api.nvim_command('stopinsert')
                    -- M.feedkeys('<Esc>', to)
                end)

                return
            end
        end
        if to ~= from and mode ~= 'P' then
            local t = M.get_current_terminal()
            if not is_user_editing and (t == nil or M.remote_state(t) ~= 'disconnected') then
                M.enter_mode(to)
            end
        end
    end
})

M.feedkeys = function(what, mode)
    local codes = vim.api.nvim_replace_termcodes(what, true, false, true)
    vim.api.nvim_feedkeys(codes, mode, false)
end

L.is_vim_mode = function(m)
    return (m:match("^[nvxoitc]") and true) or false
end

L.get_real_mode = function(m)
    return (L.is_vim_mode(m) and m) or (workflow == 'tmux' and 'n') or 't'
end

local do_set_key_map = function(map_mode, ls, rs, options)
    local map = funcs.find(function(m)
        return m.m == map_mode and funcs.compare_shortcuts(m.ls, ls)
    end, mode_mappings)
    local _mode = L.get_real_mode(map_mode)
    if map == nil then
        table.insert(mode_mappings, {
            m = map_mode, ls = ls, rs = rs, options = options, real_mode = _mode, action = options.action
        })
    else
        map.m = map_mode
        map.ls = ls
        map.rs = rs
        map.options = options
        map.real_mode = _mode
        map.action = options.action
    end
end

M.remove_key_map = function(m, ls)
    mode_mappings = vim.tbl_filter(function(_m) return _m.m ~= m or not funcs.compare_shortcuts(_m.ls, ls) end, mode_mappings)
end

--- Sets a new keymap
---
---@param mode string|table The mode for which to set the shortcut
---@param ls string The left side of the mapping
---@param rs string the right side of the mapping
---@param options table the options of the mapping
---
---@see vim.api.nvim_set_keymap
M.set_key_map = function(mode, ls, rs, options)
    local modes = mode
    if type(mode) == "string" then
        modes = {mode}
    end

    for _, m in ipairs(modes) do
        do_set_key_map(m, ls, rs, options)
    end
end

--- Returns the list of all active terminals
---@return table terminals
M.get_terminals = function()
    return terminals
end

M.select_pane = function(buf)
    vim.api.nvim_command(vim.fn.bufwinnr(buf) .. "wincmd w")
end

local get_row_or_col = function(t, check)
    if t == nil then
        return nil
    end
    local result = t.win_config[check]
    if type(result) ~= 'number' then
        return t.win_config[check][false]
    end

    return result
end

M.select_next_pane = function(dir, group)
    if funcs.are_floats_hidden(group, terminals) then
        local which = (dir == "left" and 'h') or (dir == 'right' and 'l') or (dir == 'up' and 'k') or (dir == 'down' and 'j') or ''
        vim.fn.timer_start(1, function()
            vim.api.nvim_command('wincmd ' .. which)
            vim.fn.timer_start(1, function()
                M.update_titles()
            end)
        end)
        return
    end

    local crt = M.get_current_terminal()
    local found = nil

    local check1 = ((dir == "left" or dir == "right") and 'col') or 'row'
    local check2 = (check1 == 'col' and 'row') or 'col'
    local factor = ((dir == "left" or dir == "up") and 1) or -1
    local c1 = get_row_or_col(crt, check1) * factor
    local c2 = get_row_or_col(crt, check2)
    for _, t in ipairs(vim.tbl_filter(function(t) return t ~= crt and funcs.is_float(t) and t.win_id ~= nil end, terminals)) do
        local t1 = get_row_or_col(t, check1) * factor
        local t2 = get_row_or_col(t, check2)
        if found == nil and t1 >= c1 then
            goto continue
        end
        local f1 = get_row_or_col(found, check1)
        if f1 ~= nil then
            f1 = f1 * factor
        end
        local f2 = get_row_or_col(found, check2)
        if found == nil or (t1 < c1 and (t1 > f1 or (t1 == f1 and math.abs(t2 - c2) < math.abs(f2 - c2)))) then
            found = t
        end
        ::continue::
    end

    if found == nil then
        return
    end

    vim.fn.timer_start(1, function()
        M.select_pane(funcs.get_real_buffer(found))
        vim.fn.timer_start(1, function()
            M.update_titles()
        end)
    end)
end

M.current_mode = function()
    local t = M.get_current_terminal()
    if t ~= nil and (mode == 'i' or mode == 'n' or mode == 'a') and M.remote_state(t) == 'disconnected' then
        return 't'
    end
    return mode
end

M.send_to_buf = function(buf, data, escape)
    local t = funcs.find(function(t) return t.buf == buf end, terminals)
    if t == nil then
        return
    end

    local _data = data
    if escape then
        _data = vim.api.nvim_replace_termcodes(data, true, false, true)
    end
    vim.api.nvim_chan_send(t.term_id, _data)
end

M.send_to_current = function(data, escape)
    M.send_to_buf(vim.fn.bufnr(), data, escape)
end

M.split = function(dir)
    local t = M.get_current_terminal()
    if funcs.is_float(t) then
        EV.error("You can only split an embeded pane", nil)
        return
    end
    H.add_to_history(M.term_by_buf_id(vim.fn.bufnr("%")), "split", {dir}, t.tab_id)
    local cmd = 'new'
    if dir == 'left' or dir == 'right' then
        cmd = 'v' .. cmd
    end

    local splitright = vim.o.splitright
    local splitbelow = vim.o.splitbelow

    if dir == 'right' then
        vim.o.splitright = true
    end

    if dir == 'down' then
        vim.o.splitbelow = true
    end

    vim.api.nvim_command(cmd)
    M.open(false)
    vim.fn.timer_start(1, function()
        M.update_titles()
    end)
    vim.o.splitright = splitright
    vim.o.splitbelow = splitbelow
end

M.redraw = function()
    local lines = vim.o.lines
    vim.api.nvim_command('set lines=' .. (lines - 1))
    vim.fn.timer_start(100, function()
        vim.api.nvim_command('set lines=' .. lines)
    end)
end

M.set_workflow = function(w, m)
    mod = m or '<C-s>'
    workflow = w
end

M.suspend = function()
    is_suspended = true
end

M.resume = function()
    is_suspended = false
end

M.resize = function(direction)
    local t = M.get_current_terminal()
    H.add_to_history(M.term_by_buf_id(vim.fn.bufnr('%')), "resize", {direction}, t.tab_id)
    local args = {
        left = 'vert res -5',
        right = 'vert res +5',
        up = 'res -5',
        down = 'res +5',
    }
    vim.api.nvim_command(args[direction])
    M.refresh_win_config(t)
    EV.trigger_event('PaneResized', {t, direction})
end

--- Disconnects the current session.
M.disconnect = function()
    vim.api.nvim_command('detach')
    -- for _, ui in ipairs(vim.tbl_filter(function(x) return not x.stdout_tty and x.chan end, vim.api.nvim_list_uis())) do
    --     vim.fn.timer_start(1, function()
    --         vim.fn.chanclose(ui.chan)
    --     end)
    -- end
end

M.term_by_buf_id = function(id)
    return funcs.find(function(t) return funcs.get_real_buffer(t) == 1 * id end, terminals)
end

L.terms_by_tab_id = function(id)
    return vim.tbl_filter(function(x) return x.tab_id == id end, M.get_terminals())
end

M.set_win_id = function(id)
    local t = M.term_by_buf_id(vim.fn.bufnr('%'))
    t.azul_win_id = id
    M.update_titles()
    EV.trigger_event('WinIdSet', {id})
end

M.set_tab_variable = function(key, value)
    vim.t[key] = value
end

M.set_cmd = function(cmd)
    local t = M.term_by_buf_id(vim.fn.bufnr('%'))
    t.azul_cmd = cmd
    M.update_titles()
    EV.trigger_event('CommandSet', {cmd})
end

M.get_current_workflow = function()
    return workflow
end

M.paste_from_clipboard = function()
    M.send_to_current(vim.fn.getreg("+"))
end

local snapshot = function(buf)
    local t = M.term_by_buf_id(buf)
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    local height = vim.fn.winheight(t.win_id)
    if #lines <= height then
        return {}
    end
    local length = #lines - height

    while #lines > length do
        table.remove(lines, #lines)
    end

    return lines
end

local snapshot_equals = function(new_lines, existing_lines)
    local i = 1
    while i <= #new_lines do
        if new_lines[i] ~= existing_lines[i] then
            return false
        end
        i = i + 1
    end

    return true
end

local function diff(new_lines, existing_lines)
    if snapshot_equals(new_lines, existing_lines) then
        local result = {}
        local j = #new_lines + 1
        while j <= #existing_lines do
            table.insert(result, existing_lines[j])
            j = j + 1
        end

        return result
    end

    if #new_lines == 0 then
        return existing_lines
    end

    table.remove(new_lines, 0)
    return diff(new_lines, existing_lines)
end

L.is_logging_started = function(buf)
    return loggers[buf .. ''] ~= nil
end

local append_log = function(buf)
    if not L.is_logging_started(buf) then
        return
    end
    local logger = loggers[buf .. '']
    local lines = snapshot(buf)
    if #lines == 0 then
        return
    end
    local to_write = diff(logger.lines, lines)
    logger.lines = lines
    if #to_write == 0 then
        return
    end
    local where = logger.location
    local f = io.open(where, 'a+')
    if f == nil then
        return
    end
    for _, line in ipairs(to_write) do
        f:write(line .. "\n")
    end
    f:close()

end

M.start_logging = function(where)
    local t = M.get_current_terminal()
    if t == nil then
        return
    end
    local id = cmd({'TextChangedT'}, {
        buffer = t.buf, callback = function(ev)
            append_log(ev.buf)
        end
    })
    loggers[t.buf .. ''] = {
        location = where,
        buffer = t.buf,
        lines = snapshot(t.buf),
        autocmd = id,
    }
end

M.stop_logging = function()
    local t = M.get_current_terminal()
    if t == nil or not L.is_logging_started(t.buf) then
        return
    end

    vim.api.nvim_del_autocmd(loggers[t.buf .. ''].autocmd)
    loggers[t.buf .. ''] = nil
end

M.toggle_passthrough = function(escape)
    if M.current_mode() ~= 'P' then
        if escape ~= nil then
            L.passthrough_escape = escape
        end
        M.enter_mode('P')
    else
        M.enter_mode('t')
    end
end

M.rotate_panel = function()
    local t = M.get_current_terminal()
    H.add_to_history(M.term_by_buf_id(vim.fn.bufnr("%")), "rotate_panel", nil, t.tab_id)
    vim.api.nvim_command('wincmd x')
end

M.get_mode_mappings = function()
    return mode_mappings
end

M.user_input = function(opts, callback, force)
    if not options.use_dressing then
        vim.fn.timer_start(1, function()
            EV.trigger_event('UserInputPrompt')
        end)
    end
    vim.ui.input(opts, function(input)
        if (input ~= nil and input ~= '') or force then
            callback(input)
        end
        EV.trigger_event("UserInput", {input})
    end)
end

M.get_file = function(callback)
    M.user_input({prompt = "Select a file:" .. ((options.use_dressing and '') or ' '), completion = "file"}, callback);
end

L.get_all_vars = function(vars, idx, placeholders, resulted_placeholders, prompt_ctx, when_finished)
    if idx > #vars then
        when_finished()
        return
    end

    local advance = function()
        L.get_all_vars(vars, idx + 1, placeholders, resulted_placeholders, prompt_ctx, when_finished)
    end

    local which = vars[idx]
    if placeholders[which] ~= nil then
        resulted_placeholders[which] = placeholders[which]
        advance()
    else
        M.user_input({prompt = 'Value for ' .. which .. ' (' .. prompt_ctx .. ')'}, function(response)
            resulted_placeholders[which] = (response == nil and '_') or response
            advance()
        end, true)
    end

end

local replace_placeholder = function(placeholders, which, where)
    if placeholders[which] == nil then
        return where
    end

    return where:gsub(':' .. which .. ':', placeholders[which])
end

M.parse_custom_title = function(title, placeholders, prompt_ctx, callback)
    local result = title or ''
    local p = ':([a-z_%-A-Z]+):'
    local vars = {}
    for m in result:gmatch(p) do
        if not vim.tbl_contains(vars, m) then
            table.insert(vars, m)
        end
    end

    local _placeholders = {}
    L.get_all_vars(vars, 1, placeholders, _placeholders, prompt_ctx, function()
        for p, _ in pairs(_placeholders) do
            result = replace_placeholder(_placeholders, p, result)
        end
        callback(result, _placeholders)
    end)
end

M.rename_tab = function(tab)
    local tab_id = vim.api.nvim_list_tabpages()[tab]
    local def = get_tab_title(tab)
    M.user_input({prompt = "Tab new name: ", default = def}, function(result)
        if result == '' then
            TABS.del_var(tab_id, 'azul_tab_title_overriden')
        elseif result ~= nil then
            TABS.del_var(tab_id, 'azul_placeholders')
            TABS.set_var(tab_id, 'azul_tab_title_overriden', result)
        end
        M.update_titles()
    end, true)
end

M.rename_current_tab = function()
    M.rename_tab(vim.fn.tabpagenr())
end

M.edit = function(t, file, on_finish)
    if t.editing_buf ~= nil then
        EV.error('The current terminal is already displaying an editor')
    end
    M.suspend()
    local buf = vim.api.nvim_create_buf(false, true)
    t.editing_buf = buf
    vim.api.nvim_win_set_buf(t.win_id, buf)
    local on_exit = function()
        M.suspend()
        t.editing_buf = nil
        vim.api.nvim_win_set_buf(t.win_id, t.buf)
        vim.fn.timer_start(10, function()
            M.resume()
            M.refresh_buf(t.buf)
            if on_finish ~= nil then
                on_finish()
            end
        end)
    end
    local opts = {
        cdw = vim.fn.getcwd(),
        on_exit = on_exit
    }
    local safe, _ = pcall(function()
        vim.fn.termopen({options.editor or os.getenv('EDITOR'), file}, opts)
    end)
    if not safe then
        on_exit()
        EV.error("The EDITOR variable does not seem to be set properly.")
    end
    M.resume()
    EV.trigger_event('Edit', {t, file})
end

M.edit_scrollback = function(t)
    local lines = table.concat(vim.api.nvim_buf_get_lines(t.buf, 0, -1, false), "\n")
    local file = os.tmpname()
    FILES.write_file(file, lines)
    M.edit(t, file, function()
        os.remove(file)
    end)
end

M.edit_scrollback_log = function(t)
    if not L.is_logging_started(t.buf) then
        EV.error("The current buffer is not being logged", nil)
    end
    M.edit(t, loggers[t.buf .. ''].location)
end

M.edit_current_scrollback = function()
    M.edit_scrollback(M.get_current_terminal())
end

M.edit_current_scrollback_log = function()
    M.edit_scrollback_log(M.get_current_terminal())
end

M.get_current_modifier = function()
    return mod
end

M.run_map = function(m)
    if m.options.callback ~= nil then
        m.options.callback()
    elseif m.rs ~= nil then
        M.feedkeys(m.rs, m.real_mode)
    end
    if m.action ~= nil then
        EV.trigger_event('ActionRan', {m.action})
        if funcs.find(function(a) return a == m.action end, {'select_terminal', 'select_session', 'create_tab', 'tab_select', 'toggle_floats', 'create_float', 'rename_tab', 'edit_scrollback', 'edit_scrollback_log', 'remote_scroll'}) then
            M.enter_mode('t')
        end
    end
end

M.is_modifier_mode = function(m)
    if workflow ~= 'tmux' and workflow ~= 'azul' then
        return false
    end

    return (workflow == 'tmux' and (m == 'n' or m == 'a')) or (workflow == 'azul' and m == 't')
end

local just_close_windows = function(floats)
    M.suspend()
    for _, f in ipairs(floats) do
        funcs.safe_close_window(f.win_id)
        f.win_id = nil
    end
    M.resume()
end

local just_open_windows = function(floats)
    M.suspend()
    table.sort(floats, function(a, b) return a.last_access < b.last_access end)
    for _, f in ipairs(floats) do
        f.win_id = vim.api.nvim_open_win(f.buf, true, f.win_config)
    end
    M.resume()
end

M.select_tab = function(n)
    local hidden = funcs.are_floats_hidden(funcs.current_float_group(), terminals)
    local floats = funcs.get_visible_floatings(terminals)
    if not hidden then
        just_close_windows(floats)
    end
    local safe, result = pcall(function()
        vim.api.nvim_command('tabn ' .. n)
    end)
    if not safe then
        EV.error(result)
        return
    end
    floats = vim.tbl_filter(function(t) return funcs.is_float(t) and t.group == funcs.current_float_group() end, terminals)
    if not hidden then
        just_open_windows(floats)
    else
        M.select_current_pane(TABS.get_var(0, 'azul_tab_id'))
    end
end

M.clear_mappings = function()
    mode_mappings = {}
end

M.create_tab = function()
    M.open()
    vim.fn.timer_start(1, function()
        EV.trigger_event('TabCreated')
    end)
end

M.create_tab_remote = function()
    M.open_remote()
end

M.do_open_remote = function(force, callback)
    local when_done = function(result)
        remote_command = funcs.remote_command(result)
        if remote_command == nil then
            return
        end
        callback()
    end
    if force == true or not funcs.is_handling_remote() then
        M.user_input({prompt = "Please enter a remote connection:"}, function(result)
            if result == nil or result == '' then
                return
            end
            when_done(result)
        end)

        return
    end

    when_done(os.getenv('AZUL_REMOTE_CONNECTION'))
end

--- Opens a new remote terminal in the current window
---
---@param force boolean If true, then always ask for the remote connection, even if the AZUL_REMOTE_CONNECTION var is set
---@param start_edit boolean If true, then start editing automatically (default true)
---@param callback function If set, then the callback will be called everytime for a new line in the terminal
M.open_remote = function(force, start_edit, callback)
    M.do_open_remote(force, function()
        M.open(start_edit, nil, callback)
    end)
end

M.remote_reconnect = function(t)
    if t.remote_command == nil then
        EV.error("The terminal " .. t.term_id .. " is not a remote terminal", nil)
        return
    end
    local old_buf = t.buf
    local id = funcs.safe_get_buf_var(t.buf, 'terminal_job_id')
    t.buf = vim.api.nvim_create_buf(false, false)
    if t.win_id ~= nil then
        vim.api.nvim_win_set_buf(t.win_id, t.buf)
    end
    vim.api.nvim_buf_delete(old_buf, {force = true})
    remote_command = t.remote_command
    if id ~= nil then
        M.suspend()
        vim.fn.jobstop(id)
        vim.fn.timer_start(1, function()
            M.resume()
        end)
    end
    M.suspend()
    M.open(true, t.buf)
    M.resume()
    EV.trigger_event('RemoteReconnected', {t})
    t.term_id = funcs.safe_get_buf_var(t.buf, 'terminal_job_id')
    M.update_titles()
end

M.remote_quit = function(t)
    t.remote_command = nil
    local term_id = funcs.safe_get_buf_var(t.buf, 'terminal_job_id')
    if term_id ~= nil then
        vim.fn.jobstop(funcs.safe_get_buf_var(t.buf, 'terminal_job_id'))
    end
    OnTermClose({buf = t.buf})
end

M.split_remote = function(force, dir)
    M.do_open_remote(force, function()
        M.split(dir)
    end)
end

M.remote_enter_scroll_mode = function()
    M.send_to_current('<C-\\><C-n>', true)
end

--- Returns the reomote state of a pane (nil means the pane is not a remote pane). If the pane is remote, it will
--- return connected or disconnected
--- @param t terminals The pane to be analyzed
M.remote_state = function(t)
    if t == nil or t.remote_command == nil then
        return nil
    end

    return (t.term_id == nil and 'disconnected') or 'connected'
end

M.stop_updating_titles = function()
    updating_titles = true
end

M.start_updating_titles = function()
    updating_titles = false
end

M.set_global_panel_id = function(id)
    panel_id = id
end

M.get_global_panel_id = function()
    return panel_id
end

M.set_global_tab_id = function(id)
    tab_id = id
end

M.get_global_tab_id = function()
    return tab_id
end

M.get_global_azul_win_id = function()
    return azul_win_id
end

M.set_global_azul_win_id = function(id)
    azul_win_id = id
end

M.copy_terminal_properties = function (src, dest, with_ids)
    local props = {'tab_page', 'win_config', 'azul_placeholders', 'group', 'overriden_title'}
    if with_ids == true then
        local ids = {'azul_win_id', 'panel_id', 'tab_id'}
        for _, id in ipairs(ids) do
            table.insert(props, id)
        end
    end

    for _, k in ipairs(props) do
        dest[k] = src[k]
    end
end

EV.persistent_on({'AzulStarted', 'LayoutRestored'}, function()
    is_started = true
end)

EV.persistent_on('PaneChanged', function(args)
    local t = args[1]
    local old = args[2]
    if funcs.is_float(old) or funcs.is_float(t) then
        return
    end

    set_current_panel(t.tab_id)
end)

EV.persistent_on('Error', function()
    M.resume()
end)

return M

