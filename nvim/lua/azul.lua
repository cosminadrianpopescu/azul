local cmd = vim.api.nvim_create_autocmd
local funcs = require('functions')
local FILES = require('files')
local options = require('options')

local M = {}

local is_suspended = false
local is_dressing = false

local updating_titles = true
local azul_started = false
local last_access = 0
local remote_command = nil
local to_save_remote_command = nil

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
local terminals = {}
local tab_id = 0
local azul_win_id = 0
local chan_buffers = {}
local panel_id = 0

local loggers = {}

local history = {}

local mode = nil
local mode_mappings = {
}
local workflow = 'azul'
local mod = nil
local global_last_status = nil
local quit_on_last = true

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
}

local persistent_events = {}

for k in pairs(events) do
    persistent_events[k] = {}
end

local L = {}

local current_win_has_no_pane = function()
    local t = L.term_by_buf_id(vim.fn.bufnr('%'))
    if t == nil then
        return vim.b.terminal_job_id == nil
    end
    return vim.b.terminal_job_id == nil and M.remote_state(t) ~= 'disconnected'
end

local add_to_history = function(buf, operation, params, tab_id)
    local t = L.term_by_buf_id(buf)
    if t == nil or M.is_float(t) then
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
end

local trigger_event = function(ev, args)
    for _, callback in ipairs(persistent_events[ev] or {}) do
        callback(args)
    end

    for _, callback in ipairs(events[ev] or {}) do
        callback(args)
    end
end

local do_exit = function()
    M.suspend()
    local channels = vim.tbl_filter(function(c) return c.mode == 'terminal' end, vim.api.nvim_list_chans())
    for _, c in ipairs(channels) do
        vim.fn.jobstop(c.id)
    end
    trigger_event('ExitAzul')
end

M.is_float = function(t)
    return t and t.win_config and t.win_config['zindex'] ~= nil
end

local do_remove_term_buf = function(buf)
    terminals = vim.tbl_filter(function(t) return t.buf ~= buf end, terminals)
end

local remove_term_buf = function(buf)
    do_remove_term_buf(buf)
    if quit_on_last and (#terminals == 0 or #vim.tbl_filter(function(t) return M.is_float(t) == false end, terminals) == 0) then
        do_exit()
        vim.api.nvim_command('quit!')
    end
end

M.debug = function(ev)
    -- print(vim.inspect(vim.tbl_filter(function(t) return M.is_float(t) end, M.get_terminals())))
    -- print(vim.inspect(vim.tbl_map(function(m) return m.ls end, vim.tbl_filter(function(x) return x.m == ev end, mode_mappings))))
    -- print("OPTIONS ARE " .. vim.inspect(options))
    -- print("LOGGERS ARE " .. vim.inspect(loggers))
    -- print("EV IS " .. vim.inspect(ev))
    -- print("WIN IS " .. vim.fn.winnr())
    -- print("WIN ID IS " .. vim.fn.win_getid(vim.fn.winnr()))
    -- print("TITLE IS ALREADY" .. vim.b.term_title)
    -- print("JOB ID IS " .. vim.b.terminal_job_id)
    -- print("MAPPINGS ARE" .. vim.inspect(mode_mappings))
    print("MAPPINGS ARE" .. vim.inspect(vim.tbl_filter(function(m) return m.m == 'P' end, mode_mappings)))
    -- print("MODE IS" .. mode)
end

local refresh_tab_page = function(t)
    if M.is_float(t) then
        return
    end
    t.tab_page = vim.api.nvim_tabpage_get_number(vim.api.nvim_win_get_tabpage(t.win_id))
end

local refresh_win_config = function(t)
    local old_config = t.win_config
    t.win_config = vim.api.nvim_win_get_config(t.win_id)
    refresh_tab_page(t)
    if t.win_config['height'] == nil then
        t.win_config.height = vim.api.nvim_win_get_height(t.win_id)
    end
    if t.win_config['width'] == nil then
        t.win_config.width = vim.api.nvim_win_get_width(t.win_id)
    end
    if old_config == nil or old_config.col ~= t.win_config.col or old_config.height ~= t.win_config.height
        or old_config.row ~= t.win_config.row or old_config.width ~= t.win_config.width then
        vim.fn.timer_start(1, function()
            trigger_event('WinConfigChanged', {t})
        end)
    end
end

local _buf = function(t)
    return t.editing_buf or t.buf
end

local refresh_buf = function(buf, with_win_id)
    local t = funcs.find(function(t) return _buf(t) == buf end, terminals)
    if t == nil then
        return nil
    end
    if with_win_id == nil or with_win_id == true then
        t.win_id = vim.fn.win_getid(vim.fn.winnr())
        refresh_win_config(t)
    end
    return t
end

local get_visible_floatings = function()
    return vim.tbl_filter(function(t) return M.is_float(t) and t.win_id ~= nil end, terminals)
end

local select_current_pane = function(tab_id)
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

local close_float = function(float)
    refresh_win_config(float)
    vim.api.nvim_win_close(float.win_id, true)
    float.win_id = nil
    vim.fn.timer_start(1, function()
        local t = M.get_current_terminal()
        if t == nil then
            return
        end
        select_current_pane(t.tab_id)
    end)
end

--- Returns the current selected terminal
---
---@return terminals|nil
M.get_current_terminal = function()
    return funcs.find(function(t) return t.is_current end, terminals)
end

local rebuild_zindex_floats = function()
    local floats = get_visible_floatings()
    table.sort(floats, function(a, b) return a.last_access < b.last_access end)
    for i, f in ipairs(floats) do
        f.win_config.zindex = i
        if f.win_id ~= nil then
            vim.api.nvim_win_set_config(f.win_id, f.win_config)
        end
    end
end

local OnEnter = function(ev)
    if is_suspended then
        return
    end
    local crt = refresh_buf(ev.buf)
    if crt == nil then
        return
    end

    vim.inspect("ENTER WITH " .. vim.inspect(ev))

    if M.is_float(crt) == false then
        M.hide_floats()
    end
    crt.last_access = last_access
    last_access = last_access + 1
    rebuild_zindex_floats()

    local is_current_terminal = (M.get_current_terminal() and M.get_current_terminal().buf) or nil
    local old = funcs.find(function(t) return t.is_current end, M.get_terminals())

    for _, t in ipairs(terminals) do
        vim.api.nvim_buf_set_option(t.buf, 'buflisted', t.win_id == crt.win_id)
        t.is_current = _buf(t) == ev.buf
        if t.is_current and _buf(t) ~= is_current_terminal then
            trigger_event('PaneChanged', {t, old})
        end
        if t.is_current and options.auto_start_logging and not L.is_logging_started(t.buf) then
            M.start_logging(os.tmpname())
        end
    end
    if not azul_started then
        azul_started = true
        trigger_event('AzulStarted')
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
    if L.term_by_buf_id(vim.fn.bufnr('%')) ~= nil and buf == nil then
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
    local opts = {
        term = true,
        cdw = vim.fn.getcwd(),
        env = {
            VIM = '',
            VIMRUNTIME='',
            TERM='st-256color'
        },
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
        local result = vim.fn.jobstart(remote_command or vim.o.shell, opts)
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
        trigger_event('RemoteDisconnected', {t})
        vim.fn.timer_start(1, function()
            refresh_buf(t.buf, false)
        end)
        return
    end
    add_to_history(ev.buf, "close", nil, t.tab_id)
    remove_term_buf(ev.buf)
    if #terminals == 0 then
        return
    end
    if t ~= nil then
        if funcs.find(function(t2) return t2.win_id == t.win_id end, terminals) == nil then
            vim.api.nvim_win_close(t.win_id, true)
        else
            vim.api.nvim_command('bnext')
        end
    end
    vim.api.nvim_buf_delete(ev.buf, {force = true})
    trigger_event("PaneClosed", {t})
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
        trigger_event('ModeChanged', {old_mode, new_mode})
    end
end

cmd({'TabNew', 'VimEnter'}, {
    pattern = "*", callback = function()
        vim.api.nvim_tabpage_set_var(0, 'azul_tab_id', tab_id)
        tab_id = tab_id + 1
    end
})

local get_tab_title = function(t)
    local overriden_title = funcs.safe_get_tab_var(t, 'azul_tab_title_overriden')
    return overriden_title or options.tab_title
end

local get_float_title = function(t)
    return t.overriden_title or options.float_pane_title
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

local update_titles = function(callback)
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
    local floats = get_visible_floatings()
    local titles_to_update = #vim.api.nvim_list_tabpages() + #floats
    local titles_updated = 0
    local current_tab_page = vim.fn.tabpagenr()
    for i, t in ipairs(vim.api.nvim_list_tabpages()) do
        local tab_placeholders = funcs.safe_get_tab_var(t, 'azul_placeholders')
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
                if funcs.safe_get_tab_var(t, 'azul_tab_title') ~= title then
                    trigger = true
                end
                vim.api.nvim_tabpage_set_var(t, 'azul_placeholders', placeholders)
                vim.api.nvim_tabpage_set_var(t, 'azul_tab_title', title)
                if trigger then
                    trigger_event('TabTitleChanged', {t, title})
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
            get_float_title(f),
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
                    trigger_event('FloatTitleChanged', {f})
                end
            end
        )
    end
end

--- Hides all the floats
--- 
--- @return nil
M.hide_floats = function()
    local floats = get_visible_floatings()
    for _, float in ipairs(floats) do
        close_float(float)
    end
    if #floats > 0 then
        trigger_event('FloatClosed')
    end
    vim.fn.timer_start(1, function()
        update_titles()
    end)
end

cmd({"VimLeave", "QuitPre"},{
    desc = "launch ExitAzul event",
    callback = do_exit,
})

cmd({'TabNew', 'TermClose', 'TabEnter'}, {
    pattern= '*', callback = function()
        vim.fn.timer_start(1, function()
            update_titles()
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
            group = L.current_group,
            tab_id = vim.api.nvim_tabpage_get_var(0, 'azul_tab_id'),
            panel_id = panel_id,
            cwd = vim.fn.getcwd(),
            azul_win_id = azul_win_id,
        }
        if to_save_remote_command ~= nil then
            new_terminal.remote_command = to_save_remote_command
        end
        table.insert(terminals, new_terminal)
        L.current_group = nil
        OnEnter(ev)
        if #history > 0 and history[#history].to == -1 then
            history[#history].to = panel_id
        else
            local t = L.term_by_buf_id(ev.buf)
            if t and not M.is_float(t) then
                add_to_history(ev.buf, "create", {}, t.tab_id)
            end
        end
        panel_id = panel_id + 1
        azul_win_id = azul_win_id + 1
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
        is_dressing = vim.o.filetype == 'DressingInput'
        if is_dressing then
            trigger_event('UserInputPrompt')
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
        vim.api.nvim_tabpage_set_var(0, 'current_buffer', vim.fn.bufnr())
    end
})

cmd({'WinNew', 'WinEnter'}, {
    pattern = "*", callback = function(ev)
        if is_suspended then
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
        local t = L.term_by_buf_id(ev.buf)
        if t == nil then
            return
        end
        if M.remote_state(t) == 'disconnected' then
            trigger_event((ev.event == 'BufLeave' and 'LeaveDisconnectedPane') or 'EnterDisconnectedPane', {t})
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
            if not is_dressing and (t == nil or M.remote_state(t) ~= 'disconnected') then
                M.enter_mode(to)
            end
        end
    end
})

local restore_float = function(t)
    if t == nil or not vim.api.nvim_buf_is_valid(_buf(t)) then
        return
    end
    vim.api.nvim_open_win(_buf(t), true, t.win_config)
    if t.editing_buf == nil then
        refresh_buf(t.buf)
    end
end

--- Shows all the floats
M.show_floats = function(group)
    local g = group or 'default'
    local floatings = vim.tbl_filter(function(t) return M.is_float(t) and t.group == g end, terminals)
    table.sort(floatings, function(a, b) return a.last_access < b.last_access end)
    for _, f in ipairs(floatings) do
        restore_float(f)
    end
    vim.fn.timer_start(1, function()
        trigger_event('FloatsVisible')
    end)
    update_titles()
end

local get_all_floats = function(group)
    return vim.tbl_filter(function(t) return M.is_float(t) and ((group ~= nil and t.group == group) or group == nil) end, terminals)
end

M.are_floats_hidden = function(group)
    local floatings = get_all_floats(group)
    if #floatings == 0 then
        return true
    end
    return #vim.tbl_filter(function(t) return t.win_id == nil and t.group == (group or 'default') end, floatings) > 0
end

--- Opens a new float
--- @param group string The group in which to open a float
--- @param opts table the options of the new window (@ses vim.api.nvim_open_win)
--- @param to_restore terminals The float terminal to restore (optional)
M.open_float = function(group, opts, to_restore)
    L.current_group = group or funcs.current_float_group()
    if #get_all_floats(group) > 0 and M.are_floats_hidden(group) then
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
        local opened = L.term_by_buf_id(buf)
        trigger_event('FloatOpened', {opened})
        if to_restore ~= nil then
            opened.azul_placeholders = to_restore.azul_placeholders or {}
            opened.overriden_title = to_restore.overriden_title
        end
        update_titles()
    end)
end

--- Toggles the visibility of the floating windows
M.toggle_floats = function(group)
    if M.are_floats_hidden(group) then
        M.show_floats(group)
    else
        M.hide_floats()
    end
    vim.fn.timer_start(1, function()
        M.enter_mode('t')
    end)
end

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

local fix_coord = function(c, max, limit)
    if c < 0 then
        return 0
    end

    if c + max >= limit - 1 then
        return limit - max - 2
    end

    return c
end

M.move_current_float = function(dir, inc)
    local buf = vim.fn.bufnr()
    local t = funcs.find(function(t) return _buf(t) == buf end, terminals)
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
    if M.are_floats_hidden(group) then
        local which = (dir == "left" and 'h') or (dir == 'right' and 'l') or (dir == 'up' and 'k') or (dir == 'down' and 'j') or ''
        vim.fn.timer_start(1, function()
            vim.api.nvim_command('wincmd ' .. which)
            vim.fn.timer_start(1, function()
                update_titles()
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
    for _, t in ipairs(vim.tbl_filter(function(t) return t ~= crt and M.is_float(t) and t.win_id ~= nil end, terminals)) do
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
        M.select_pane(_buf(found))
        vim.fn.timer_start(1, function()
            update_titles()
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
    if M.is_float(t) then
        L.error("You can only split an embeded pane", nil)
        return
    end
    add_to_history(vim.fn.bufnr("%"), "split", {dir}, t.tab_id)
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
        update_titles()
    end)
    vim.o.splitright = splitright
    vim.o.splitbelow = splitbelow
end

M.position_current_float = function(where)
    local conf = vim.api.nvim_win_get_config(0)
    local t = M.get_current_terminal()
    if not M.is_float(t) then
        L.error("You can only position a floating window", nil)
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
    refresh_win_config(t)
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
    add_to_history(vim.fn.bufnr('%'), "resize", {direction}, t.tab_id)
    local args = {
        left = 'vert res -5',
        right = 'vert res +5',
        up = 'res -5',
        down = 'res +5',
    }
    vim.api.nvim_command(args[direction])
    refresh_win_config(t)
end

--- Disconnects the current session.
M.disconnect = function()
    for _, ui in ipairs(vim.tbl_filter(function(x) return not x.stdout_tty and x.chan end, vim.api.nvim_list_uis())) do
        vim.fn.timer_start(1, function()
            vim.fn.chanclose(ui.chan)
        end)
    end
end

local deserialize = function(var)
    return loadstring("return " .. string.gsub(var, "\\n", "\n"))()
end

L.term_by_panel_id = function(id)
    return funcs.find(function(t) return t.panel_id == id end, terminals)
end

L.term_by_buf_id = function(id)
    return funcs.find(function(t) return _buf(t) == 1 * id end, terminals)
end

L.terms_by_tab_id = function(id)
    return vim.tbl_filter(function(x) return x.tab_id == id end, M.get_terminals())
end

local get_custom_values = function()
    local result = {}
    for _, t in ipairs(terminals) do
        result[t.panel_id .. ""] = {
            azul_win_id = t.azul_win_id,
            azul_cmd = t.azul_cmd or nil,
            remote_command = t.remote_command
        }
    end

    return result
end

M.save_layout = function(where)
    M.hide_floats()
    for _, t in ipairs(terminals) do
        refresh_tab_page(t)
    end
    local history_to_save = {}
    local placeholders = {}
    local title_overrides = {}
    for _, id in ipairs(vim.api.nvim_list_tabpages()) do
        table.insert(history_to_save, L.histories_by_tab_id(vim.api.nvim_tabpage_get_var(id, 'azul_tab_id'), history))
        table.insert(placeholders, funcs.safe_get_tab_var(id, 'azul_placeholders') or {})
        table.insert(title_overrides, funcs.safe_get_tab_var(id, 'azul_tab_title_overriden') or '')
    end
    local f = io.open(where, "w")
    f:write(vim.inspect({
        floats = vim.tbl_filter(function(x) return M.is_float(x) end, terminals),
        history = history_to_save,
        customs = get_custom_values(),
        azul_placeholders = placeholders,
        title_overrides = title_overrides,
    }))
    f:close()
    trigger_event("LayoutSaved")
end

L.error = function(msg, h)
    local _m = msg
    if h ~= nil then
        _m = _m .. " at " .. vim.inspect(h)
    end
    trigger_event("Error", {_m})
    -- The test environment will disable the throwing of errors
    if vim.g.azul_errors_log ~= nil then
        funcs.log(vim.inspect(_m), vim.g.azul_errors_log)
    else
        error(_m)
    end
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

L.restore_floats = function(histories, idx, panel_id_wait, timeout)
    if timeout > 100 then
        updating_titles = false
        L.error("Trying to restore a session. Waiting for " .. panel_id_wait, nil)
    end

    if panel_id_wait ~= nil then
        local t = L.term_by_panel_id(panel_id_wait)
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

    panel_id = f.panel_id
    M.open_float(f.group, f.win_config, f)

    L.restore_floats(histories, idx + 1, f.panel_id, 0)
end

L.restore_remotes = function()
    local remotes = vim.tbl_filter(function(t) return t.remote_command ~= nil end, M.get_terminals())
    for _, r in ipairs(remotes) do
        vim.fn.jobstop(r.term_id)
    end
    updating_titles = false
    update_titles()
    trigger_event("LayoutRestored")
end

L.restore_tab_history = function(histories, i, j, panel_id_wait, timeout)
    if timeout > 100 then
        updating_titles = false
        L.error("Timeout trying to restore the session. Waiting for " .. panel_id_wait, i .. ", " .. j)
    end

    if panel_id_wait ~= nil then
        local t = L.term_by_panel_id(panel_id_wait)
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
        panel_id = h.to
        tab_id = h.tab_id
        local buf = nil
        if j == 1 and i == 1 then
            buf = vim.fn.bufnr('%')
        end
        M.open(true, buf)
        vim.fn.timer_start(10, function()
            L.restore_tab_history(histories, i, j + 1, h.to, 0)
        end)
        return
    end

    if h.operation == "split" then
        panel_id = h.to
        local t = L.term_by_panel_id(h.from)
        if t == nil then
            L.error("Error found loading the layout file", h)
        end
        M.select_pane(t.buf)
        M.split(h.params[1])
        vim.fn.timer_start(10, function()
            L.restore_tab_history(histories, i, j + 1, h.to, 0)
        end)
        return
    end

    if h.operation == "close" then
        local t = L.term_by_panel_id(h.from)
        if t == nil then
            L.error("Error found loading the layout file", h)
        end
        vim.fn.chanclose(t.term_id)
        vim.fn.timer_start(10, function()
            L.restore_tab_history(histories, i, j + 1, nil, 0)
        end)
        return
    end

    if h.operation == "resize" then
        local t = L.term_by_panel_id(h.from)
        if t == nil then
            L.error("Error found loading the layout file", h)
        end
        M.select_pane(t.buf)
        M.resize(h.params[1])
        vim.fn.timer_start(10, function()
            L.restore_tab_history(histories, i, j + 1, nil, 0)
        end)
        return
    end

    if h.operation == "rotate_panel" then
        local t = L.term_by_panel_id(h.from)
        if t == nil then
            L.error("Error found loading the layout file", h)
        end
        M.select_pane(t.buf)
        M.rotate_panel()
        vim.fn.timer_start(10, function()
            L.restore_tab_history(histories, i, j + 1, nil, 0)
        end)
        return
    end
end

L.restore_ids = function(title_placeholders, title_overrides)
    panel_id = 0
    tab_id = 0
    for _, t in ipairs(terminals) do
        if t.panel_id > panel_id then
            panel_id = t.panel_id
        end
        if t.tab_id > tab_id then
            tab_id = t.tab_id
        end
    end
    panel_id = panel_id + 1
    tab_id = tab_id + 1
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

L.histories_by_tab_id = function(tab_id, history)
    return vim.tbl_filter(function(h) return h.tab_id == tab_id end, history)
end

--- Restores a saved layout
---
--- @param where string The saved file location
--- @param callback function(t) callback called after each terminal is restored. 
---                             The t is the just opened terminal
M.restore_layout = function(where, callback)
    if #terminals > 1 then
        L.error("You have already several windows opened. You can only call this function when you have no floats and only one tab opened", nil)
        return
    end
    local f = io.open(where, "r")
    if f == nil then
        L.error("Could not open " .. where, nil)
    end
    local h = deserialize(f:read("*a"))
    h.callback = callback
    updating_titles = true
    funcs.safe_del_tab_var(0, 'azul_placeholders')
    local t = M.get_current_terminal()
    local old_buf = t.buf
    t.buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_win_set_buf(t.win_id, t.buf)
    vim.fn.jobstop(t.term_id)
    vim.api.nvim_buf_delete(old_buf, {force = true})
    do_remove_term_buf(t.buf)
    L.restore_tab_history(h, 1, 1, nil, 0)
    f:close()
end

M.set_win_id = function(id)
    local t = L.term_by_buf_id(vim.fn.bufnr('%'))
    t.azul_win_id = id
    update_titles()
    trigger_event('WinIdSet', {id})
end

M.set_tab_variable = function(key, value)
    vim.t[key] = value
end

M.set_cmd = function(cmd)
    local t = L.term_by_buf_id(vim.fn.bufnr('%'))
    t.azul_cmd = cmd
    update_titles()
    trigger_event('CommandSet', {cmd})
end

M.get_current_workflow = function()
    return workflow
end

M.paste_from_clipboard = function()
    M.send_to_current(vim.fn.getreg("+"))
end

local snapshot = function(buf)
    local t = L.term_by_buf_id(buf)
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
    add_to_history(vim.fn.bufnr("%"), "rotate_panel", nil, t.tab_id)
    vim.api.nvim_command('wincmd x')
end

local add_event = function(ev, callback, where)
    local to_add = (type(ev) == 'string' and {ev}) or ev

    for _, e in ipairs(to_add) do
        if not vim.tbl_contains(vim.tbl_keys(events), e) then
            L.error(e .. " event does not exists", nil)
        end

        table.insert(where[e], callback)
    end
end

M.on = function(ev, callback)
    add_event(ev, callback, events)
end

M.clear_event = function(ev, callback)
    if not vim.tbl_contains(vim.tbl_keys(events), ev) then
        L.error(ev .. " event does not exists", nil)
    end
    if callback == nil then
        events[ev] = {}
        return
    end

    events[ev] = vim.tbl_filter(function(c) return c == callback end, events[ev])
end

M.get_mode_mappings = function()
    return mode_mappings
end

M.user_input = function(opts, callback, force)
    vim.ui.input(opts, function(input)
        if (input ~= nil and input ~= '') or force then
            callback(input)
        end
        trigger_event("UserInput", {input})
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
    M.user_input({propmt = "Tab new name: ", default = def}, function(result)
        if result == '' then
            funcs.safe_del_tab_var(tab_id, 'azul_tab_title_overriden')
        elseif result ~= nil then
            funcs.safe_del_tab_var(tab_id, 'azul_placeholders')
            vim.api.nvim_tabpage_set_var(tab_id, 'azul_tab_title_overriden', result)
        end
        update_titles()
    end, true)
end

M.rename_floating_pane = function(pane)
    if pane == nil then
        return
    end
    if not M.is_float(pane) then
        L.error('You can only rename floating panes')
    end
    local def = get_float_title(pane)
    M.user_input({propmt = "Pane new name: ", default = def}, function(result)
        if result == '' then
            pane.overriden_title = nil
            funcs.safe_del_tab_var(tab_id, 'azul_tab_title_overriden')
        elseif result ~= nil then
            pane.azul_placeholders = nil
            pane.overriden_title = result
        end
        update_titles()
    end, true)
end

M.rename_current_tab = function()
    M.rename_tab(vim.fn.tabpagenr())
end

M.rename_current_pane = function()
    local buf = vim.fn.bufnr()
    M.rename_floating_pane(funcs.find(function(t) return _buf(t) == buf end, terminals))
end

M.edit = function(t, file, on_finish)
    if t.editing_buf ~= nil then
        L.error('The current terminal is already displaying an editor')
    end
    M.suspend()
    local buf = vim.api.nvim_create_buf(false, true)
    t.editing_buf = buf
    vim.api.nvim_win_set_buf(t.win_id, buf)
    local opts = {
        cdw = vim.fn.getcwd(),
        env = {
            EDITOR = os.getenv('EDITOR'),
            VIM = '',
            VIMRUNTIME='',
        },
        on_exit = function()
            M.suspend()
            t.editing_buf = nil
            vim.api.nvim_win_set_buf(t.win_id, t.buf)
            vim.fn.timer_start(10, function()
                M.resume()
                refresh_buf(t.buf)
                if on_finish ~= nil then
                    on_finish()
                end
            end)
        end
    }
    vim.fn.termopen({os.getenv('EDITOR'), file}, opts)
    M.resume()
    trigger_event('Edit', {t, file})
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
        L.error("The current buffer is not being logged", nil)
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
        trigger_event('ActionRan', {m.action})
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
        vim.api.nvim_win_close(f.win_id, true)
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
    local hidden = M.are_floats_hidden(funcs.current_float_group())
    local floats = get_visible_floatings()
    if not hidden then
        just_close_windows(floats)
    end
    vim.api.nvim_command('tabn ' .. n)
    floats = vim.tbl_filter(function(t) return M.is_float(t) and t.group == funcs.current_float_group() end, terminals)
    if not hidden then
        just_open_windows(floats)
    else
        select_current_pane(vim.api.nvim_tabpage_get_var(0, 'azul_tab_id'))
    end
end

M.anounce_config_reloaded = function()
    update_titles()
    trigger_event('ConfigReloaded')
end

M.clear_mappings = function()
    mode_mappings = {}
end

M.create_tab = function()
    M.open()
    vim.fn.timer_start(1, function()
        trigger_event('TabCreated')
    end)
end

M.create_tab_remote = function()
    M.open_remote()
end

M.on_action = function(action, callback)
    M.on('ActionRan', function(args)
        if args[1] ~= action then
            return
        end
        callback(args[1])
    end)
end

local do_open_remote = function(force, callback)
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
    do_open_remote(force, function()
        M.open(start_edit, nil, callback)
    end)
end

M.remote_reconnect = function(t)
    if t.remote_command == nil then
        L.error("The terminal " .. t.term_id .. " is not a remote terminal", nil)
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
    trigger_event('RemoteReconnected', {t})
    t.term_id = funcs.safe_get_buf_var(t.buf, 'terminal_job_id')
    update_titles()
end

M.remote_quit = function(t)
    t.remote_command = nil
    local term_id = funcs.safe_get_buf_var(t.buf, 'terminal_job_id')
    if term_id ~= nil then
        vim.fn.jobstop(funcs.safe_get_buf_var(t.buf, 'terminal_job_id'))
    end
    OnTermClose({buf = t.buf})
end

--- Opens a new float
--- @param group string The group in which to open a float
--- @param force boolean If true, then always ask for the remote connection, even if the AZUL_REMOTE_CONNECTION var is set
--- @param opts table the options of the new window (@ses vim.api.nvim_open_win)
--- @param to_restore terminals The float terminal to restore (optional)
M.open_float_remote = function(group, force, opts, to_restore)
    do_open_remote(force, function()
        M.open_float(group, opts, to_restore)
    end)
end

M.split_remote = function(force, dir)
    do_open_remote(force, function()
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

M.persistent_on = function(ev, callback)
    add_event(ev, callback, persistent_events)
end

M.persistent_on('AzulStarted', function()
    vim.fn.timer_start(200, function()
        updating_titles = false
        update_titles()
    end)
end)

M.persistent_on('PaneChanged', function(args)
    local t = args[1]
    local old = args[2]
    if M.is_float(old) or M.is_float(t) then
        return
    end

    set_current_panel(t.tab_id)
end)

return M
