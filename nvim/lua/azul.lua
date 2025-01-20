local cmd = vim.api.nvim_create_autocmd
local map = vim.api.nvim_set_keymap
local funcs = require('functions')
local FILES = require('files')

local is_suspended = false

local updating_tab_titles = false
local azul_started = false

local M = {
    --- If set to true, then list all buffers
    list_buffers = false,
    options = nil,
}

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
--- @field win_config table The current neovim window config
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
local latest_float = {}
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
    ModifierTrigger = {},
    AboutToBeBlocked = {},
    WinConfigChanged = {},
    TabTitleChanged = {},
    AzulStarted = {},
}

local L = {}

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
    if not vim.tbl_contains(vim.tbl_keys(events), ev) then
        return
    end

    for _, callback in ipairs(events[ev]) do
        callback(args)
    end
end

M.is_float = function(t)
    return t and t.win_config and t.win_config['zindex'] ~= nil
end

local remove_term_buf = function(buf)
    terminals = vim.tbl_filter(function(t) return t.buf ~= buf end, terminals)
    if quit_on_last and (#terminals == 0 or #vim.tbl_filter(function(t) return M.is_float(t) == false end, terminals) == 0) then
        vim.api.nvim_command('quit!')
    end
end

M.debug = function(ev)
    print(vim.inspect(vim.tbl_filter(function(t) return M.is_float(t) end, M.get_terminals())))
    -- print(vim.inspect(vim.tbl_map(function(m) return m.ls end, vim.tbl_filter(function(x) return x.m == ev end, mode_mappings))))
    -- print("OPTIONS ARE " .. vim.inspect(M.options))
    -- print("LOGGERS ARE " .. vim.inspect(loggers))
    -- print("EV IS " .. vim.inspect(ev))
    -- print("WIN IS " .. vim.fn.winnr())
    -- print("WIN ID IS " .. vim.fn.win_getid(vim.fn.winnr()))
    -- print("TITLE IS ALREADY" .. vim.b.term_title)
    -- print("JOB ID IS " .. vim.b.terminal_job_id)
    -- print("LATEST FLOATS ARE " .. vim.inspect(latest_float))
    -- print("MAPPINGS ARE" .. vim.inspect(mode_mappings))
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

local refresh_buf = function(buf)
    local t = funcs.find(function(t) return _buf(t) == buf end, terminals)
    if t == nil then
        return nil
    end
    t.win_id = vim.fn.win_getid(vim.fn.winnr())
    refresh_win_config(t)
    return t
end

local get_visible_floatings = function()
    return vim.tbl_filter(function(t) return M.is_float(t) and t.win_id ~= nil end, terminals)
end

local close_float = function(float)
    refresh_win_config(float)
    vim.api.nvim_win_close(float.win_id, true)
    float.win_id = nil
end

--- Returns the current selected terminal
---
---@return terminals|nil
M.get_current_terminal = function()
    return funcs.find(function(t) return t.is_current end, terminals)
end

--- Hides all the floats
M.hide_floats = function()
    local crt = M.get_current_terminal()
    if crt ~= nil and M.is_float(crt) then
        latest_float[crt.group] = crt
    end

    local floats = get_visible_floatings()
    for _, float in ipairs(floats) do
        close_float(float)
    end
    if #floats > 0 then
        trigger_event('FloatClosed')
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

    if M.is_float(crt) == false then
        M.hide_floats()
    end
    crt.last_access = os.time(os.date("!*t"))

    local is_current_terminal = (M.get_current_terminal() and M.get_current_terminal().buf) or nil

    for _, t in ipairs(terminals) do
        if not M.list_buffers then
            vim.api.nvim_buf_set_option(t.buf, 'buflisted', t.win_id == crt.win_id)
        end
        t.is_current = _buf(t) == ev.buf
        if t.is_current and _buf(t) ~= is_current_terminal then
            trigger_event('PaneChanged', {t})
        end
        if t.is_current and M.options.auto_start_logging and not L.is_logging_started(t.buf) then
            M.start_logging(os.tmpname())
        end
    end
    if workflow == 'emacs' or workflow == 'azul' then
        vim.api.nvim_command('startinsert')
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
---@param force boolean If true, then open the terminal without opening a new tab in the current place
---@param callback function If set, then the callback will be called everytime for a new line in the terminal
M.open = function(start_edit, force, callback)
    if L.term_by_buf_id(vim.fn.bufnr('%')) ~= nil and not force then
        L.open_params = {start_edit, force, callback}
        vim.api.nvim_command('$tabnew')
        return
    end
    if L.open_params ~= nil then
        start_edit = L.open_params[1]
        force = L.open_params[2]
        callback = L.open_params[3]
        L.open_params = nil
    end
    local opts = {
        cdw = vim.fn.getcwd(),
        env = {
            VIM = '',
            VIMRUNTIME='',
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
    vim.fn.termopen(vim.o.shell, opts)
    if type(start_edit) == 'boolean' and start_edit == false then
        return
    end
    vim.api.nvim_command('startinsert')
end

local OnTermClose = function(ev)
    if is_suspended then
        return
    end
    local t = funcs.find(function(t) return t.buf == ev.buf end, terminals)
    if t == nil then
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

local session_child_file = function(for_parent)
    return os.getenv('AZUL_RUN_DIR') .. '/' .. os.getenv((for_parent and 'AZUL_PARENT_SESSION') or 'AZUL_SESSION') .. '-child'
end

local has_child_sessions_in_passthrough = function()
    local f = session_child_file()
    if not FILES.exists(f) then
        return false
    end

    local content = FILES.read_file(f)
    return content:gsub('[\n\r\t]', '') == 'true'
end

local anounce_passthrough = function()
    local f = session_child_file(true)
    if not FILES.exists(f) then
        return
    end
    FILES.write_file(f, "true")
end

local recall_passthrough = function()
    local f = session_child_file(true)
    if not FILES.exists(f) then
        return
    end
    FILES.write_file(f, "")
end

--- Enters a custom mode. Use this function for changing custom modes
---@param new_mode 'p'|'r'|'s'|'m'|'T'|'n'|'t'|'v'|'P'
M.enter_mode = function(new_mode)
    local old_mode = mode
    L.unmap_all(mode)
    if mode == 'P' then
        if M.options.hide_in_passthrough then
            vim.o.laststatus = global_last_status
        end
        recall_passthrough()
        vim.api.nvim_command('tunmap ' .. (L.passthrough_escape or M.options.passthrough_escape))
        L.passthrough_escape = nil
    end
    mode = new_mode
    if mode == 'P' then
        vim.fn.timer_start(1, function()
            if workflow == 'tmux' then
                vim.api.nvim_command('startinsert')
            end
            if M.options.hide_in_passthrough then
                global_last_status = vim.o.laststatus
                vim.o.laststatus = 0
            end
        end)
        anounce_passthrough()
        map('t', (L.passthrough_escape or M.options.passthrough_escape), '', {
            callback = function()
                if has_child_sessions_in_passthrough() then
                    M.send_to_current('<C-\\><C-s>', true)
                    return
                end
                M.enter_mode('t')
            end
        })
    end
    trigger_event('ModeChanged', {old_mode, new_mode})
    L.remap_all(new_mode)
    if L.is_vim_mode(new_mode) then
        return
    end

    local real_mode = L.get_real_mode(new_mode)
    if real_mode ~= new_mode and workflow ~= 'tmux' then
        M.suspend()
        vim.api.nvim_command('startinsert')
        M.resume()
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
    return overriden_title or M.options.tab_title
end

local update_tab_titles = function()
    if updating_tab_titles or not azul_started then
        return
    end
    updating_tab_titles = true
    local tabs_to_update = #vim.api.nvim_list_tabpages()
    local tabs_updated = 0
    local current_tab_page = vim.fn.tabpagenr()
    for i, t in ipairs(vim.api.nvim_list_tabpages()) do
        local tab_placeholders = funcs.safe_get_tab_var(t, 'azul_title_placeholders')
        local placeholders = vim.tbl_extend(
            'keep', { tab_n = i, term_title = vim.b.term_title, is_current = (i == current_tab_page and '*') or '' },
            tab_placeholders or {}
        )
        M.parse_custom_title(
            get_tab_title(t),
            placeholders,
            'for tab ' .. i,
            function(title, placeholders)
                tabs_updated = tabs_updated + 1
                if tabs_updated >= tabs_to_update then
                    updating_tab_titles = false
                end
                vim.api.nvim_tabpage_set_var(t, 'azul_title_placeholders', placeholders)
                vim.api.nvim_tabpage_set_var(t, 'azul_tab_title', title)
                trigger_event('TabTitleChanged')
            end
        )
    end
end

cmd({'TabNew', 'TermClose', 'TabEnter'}, {
    pattern= '*', callback = function()
        vim.fn.timer_start(1, update_tab_titles)
    end
})

cmd('TermOpen',{
    pattern = "*", callback = function(ev)
        if is_suspended or #vim.tbl_filter(function(x) return x.term_id == vim.b.terminal_job_id end, terminals) > 0 then
            return
        end
        table.insert(terminals, {
            is_current = false,
            buf = ev.buf,
            win_id = vim.fn.win_getid(vim.fn.winnr()),
            term_id = vim.b.terminal_job_id,
            group = L.current_group,
            tab_id = vim.api.nvim_tabpage_get_var(0, 'azul_tab_id'),
            panel_id = panel_id,
            cwd = vim.fn.getcwd(),
            azul_win_id = azul_win_id,
        })
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

cmd({'FileType'}, {
    pattern = "*", callback = function()
        if vim.o.filetype ~= 'DressingInput' then
            return
        end
        vim.fn.timer_start(1, function()
            M.feedkeys('i', 'n')
            trigger_event('ModeChanged', {'t', 'n'})
        end)
    end
})

cmd({'WinEnter'}, {
    pattern = "term://*", callback = function(ev)
        if is_suspended then
            return
        end
        vim.fn.timer_start(1, function()
            ev.buf = vim.fn.bufnr()
            if vim.b.terminal_job_id == nil then
                M.open(false)
            end
            OnEnter(ev)
        end)
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

cmd({'WinNew'}, {
    pattern = "term://*", callback = function()
        if is_suspended then
            return
        end
        vim.fn.timer_start(1, function()
            if vim.b.terminal_job_id == nil then
                M.open(false)
            end
        end)
    end
})

cmd({'ModeChanged'}, {
    pattern = {'*'}, callback = function(ev)
        if is_suspended then
            return
        end
        local to = string.gsub(ev.match, '^[^:]+:(.*)', '%1'):sub(1, 1)
        local from = string.gsub(ev.match, '^([^:]+):.*', '%1'):sub(1, 1)
        if to ~= from and mode ~= 'P' then
            M.enter_mode(to)
        end
    end
})

cmd({'UiEnter'}, {
    pattern = {'*'}, callback = function(_)
        -- M.feedkeys('<C-\\><C-n>i', 't')
        -- vim.fn.timer_start(1, function()
        --     M.enter_mode('')
        --     vim.api.nvim_command('startinsert')
        -- end)
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

L.do_show_floats = function(floatings, idx, after_callback)
    if idx > #floatings then
        if after_callback ~= nil then
            after_callback()
        end
        trigger_event('FloatsVisible')
        return
    end
    restore_float(floatings[idx])
    vim.fn.timer_start(10, function()
        L.do_show_floats(floatings, idx + 1, after_callback)
    end)
end

--- Shows all the floats
M.show_floats = function(group, after_callback)
    local g = group or 'default'
    local floatings = vim.tbl_filter(function(t) return M.is_float(t) and t ~= latest_float[g] and t.group == g end, terminals)
    table.sort(floatings, function(a, b) return a.last_access < b.last_access end)
    if latest_float[g] ~= nil then
        floatings[#floatings + 1] = latest_float[g]
    end
    L.do_show_floats(floatings, 1, after_callback)
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
M.open_float = function(group, opts)
    local after = function()
        local buf = vim.api.nvim_create_buf(true, false)
        local factor = 4
        local w = (vim.o.columns - factor) / 2
        local h = (vim.o.lines - factor) / 2
        local x = (vim.o.columns - w) / 2
        local y = (vim.o.lines - h) / 2
        local _opts = {
            width = math.floor(w), height = math.floor(h), col = math.floor(x), row = math.floor(y),
            focusable = true, zindex = 1, border = 'rounded', title = vim.b.term_title, relative = 'editor', style = 'minimal'
        }
        for k, v in pairs(opts or {}) do
            _opts[k] = v
        end
        vim.api.nvim_open_win(buf, true, _opts)
        trigger_event('FloatOpened', {L.term_by_buf_id(buf)})
    end
    L.current_group = group or 'default'
    if #get_all_floats(group) > 0 and M.are_floats_hidden(group) then
        M.show_floats(group, after)
    else
        after()
    end
end

--- Toggles the visibility of the floating windows
M.toggle_floats = function(group)
    if M.are_floats_hidden(group) then
        M.show_floats(group)
    else
        M.hide_floats()
    end
end

M.feedkeys = function(what, mode)
    local codes = vim.api.nvim_replace_termcodes(what, true, false, true)
    vim.api.nvim_feedkeys(codes, mode, false)
end

L.is_vim_mode = function(m)
    return (m:match("^[nvxoitc]") and true) or false
end

L.get_real_mode = function(m)
    return (L.is_vim_mode(m) and m) or ((workflow == 'tmux' and 'n') or 't')
end

local do_set_key_map = function(map_mode, ls, rs, options)
    local map = funcs.find(function(m)
        return m.m == map_mode and funcs.get_sensitive_ls(m.ls) == funcs.get_sensitive_ls(ls)
    end, mode_mappings)
    local _mode = L.get_real_mode(map_mode)
    if map == nil then
        table.insert(mode_mappings, {
            m = map_mode, ls = ls, rs = rs, options = options, real_mode = _mode
        })
    else
        map.m = map_mode
        map.ls = ls
        map.rs = rs
        map.options = options
        map.real_mode = _mode
    end
end

M.remove_key_map = function(m, ls)
    mode_mappings = vim.tbl_filter(function(_m) return _m.m ~= m or _m.ls ~= ls end, mode_mappings)
end

L.unmap_all = function(mode)
    if ((workflow == 'azul' and mode == 't') or (workflow == 'tmux' and mode == 'n')) and M.options.use_cheatsheet then
        return
    end
    local cmds = {}
    local collection = vim.tbl_filter(function(x) return x.m == mode end, mode_mappings)
    local pref = (workflow == 'azul' and mode == 't' and mod) or ''
    for _, m in ipairs(collection) do
        local cmd = m.real_mode .. 'unmap ' .. pref .. m.ls
        if vim.tbl_contains(cmds, cmd) == false then
            local result = pcall(function() vim.api.nvim_command(cmd) end)
            if not result then
                print(cmd .. " failed")
            end
            table.insert(cmds, cmd)
        end
    end
end

L.remap_all = function(mode)
    if ((workflow == 'azul' and mode == 't') or (workflow == 'tmux' and mode == 'n')) and M.options.use_cheatsheet then
        return
    end
    local collection = vim.tbl_filter(function(x) return x.m == mode end, mode_mappings)
    local pref = (workflow == 'azul' and mode == 't' and mod) or ''
    for _, m in ipairs(collection) do
        vim.api.nvim_set_keymap(m.real_mode, pref .. m.ls, m.rs, m.options)
    end
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
    end)
end

M.current_mode = function()
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

M.set_workflow = function(w, _use_cheatsheet, m)
    local cheatsheet = (_use_cheatsheet == nil) or _use_cheatsheet
    mod = m or '<C-s>'
    workflow = w
    if workflow == 'tmux' and not cheatsheet then
        vim.api.nvim_set_keymap('t', mod, '', {
            callback = function()
                M.enter_mode('n')
                M.feedkeys('<C-\\><C-n>', 't')
            end
        })
    elseif (workflow == 'azul' or workflow == 'tmux') and cheatsheet then
        vim.api.nvim_set_keymap('t', mod, '', {
            callback = function()
                if mode == 'P' then
                    M.send_to_current(mod, true)
                    return
                end
                if workflow == 'tmux' then
                    M.enter_mode('n')
                    M.feedkeys('<C-\\><C-n>', 't')
                end
                trigger_event('ModifierTrigger', {(workflow == 'azul' and 't') or 'n', mod})
            end,
            desc = '',
        })
    end
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
end

--- Disconnects the current session.
M.disconnect = function()
    for _, ui in ipairs(vim.tbl_filter(function(x) return not x.stdout_tty and x.chan end, vim.api.nvim_list_uis())) do
        vim.fn.chanclose(ui.chan)
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

local get_custom_values = function()
    local result = {}
    for _, t in ipairs(terminals) do
        result[t.panel_id .. ""] = {
            azul_win_id = t.azul_win_id,
            azul_cmd = t.azul_cmd or nil,
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
        table.insert(placeholders, funcs.safe_get_tab_var(id, 'azul_title_placeholders') or {})
        table.insert(title_overrides, funcs.safe_get_tab_var(id, 'azul_tab_title_overriden') or '')
    end
    local f = io.open(where, "w")
    f:write(vim.inspect({
        floats = vim.tbl_filter(function(x) return M.is_float(x) end, terminals),
        history = history_to_save,
        customs = get_custom_values(),
        azul_title_placeholders = placeholders,
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
    error(_m)
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

    if callback ~= nil then
        callback(t, t.azul_win_id)
    end

    if t.azul_cmd ~= nil then
        local _cmd = t.azul_cmd .. '<cr>'
        vim.fn.timer_start(1000, function()
            M.send_to_buf(t.buf, _cmd, true)
        end)
    end
end

L.restore_floats = function(histories, idx, panel_id_wait, timeout)
    if timeout > 100 then
        updating_tab_titles = false
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
        L.restore_ids(histories.azul_title_placeholders, histories.title_overrides)
        return
    end

    local f = histories.floats[idx]

    panel_id = f.panel_id
    M.open_float(f.group, f.win_config)

    L.restore_floats(histories, idx + 1, f.panel_id, 0)
end

L.restore_tab_history = function(histories, i, j, panel_id_wait, timeout)
    if timeout > 100 then
        updating_tab_titles = false
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

    if h.operation == "create" and j == 1 and i == 1 then
        history = {}
        terminals[1].panel_id = h.to
        terminals[1].tab_id = h.tab_id
        post_restored(terminals[1], histories.customs, histories.callback)
        vim.api.nvim_tabpage_set_var(0, 'azul_tab_id', h.tab_id)
        add_to_history(terminals[1].buf, "create", {}, h.tab_id)
        L.restore_tab_history(histories, i, j + 1, nil, 0)
        return
    end

    if h.operation == "create" then
        panel_id = h.to
        tab_id = h.tab_id
        M.open()
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
        vim.api.nvim_tabpage_set_var(vim.api.nvim_list_tabpages()[i], 'azul_title_placeholders', p)
    end
    for i, o in ipairs(title_overrides or {}) do
        if o ~= '' then
            vim.api.nvim_tabpage_set_var(vim.api.nvim_list_tabpages()[i], 'azul_tab_title_overriden', o)
        end
    end
    updating_tab_titles = false
    update_tab_titles()
    trigger_event("LayoutRestored")
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
    end
    local f = io.open(where, "r")
    if f == nil then
        L.error("Could not open " .. where, nil)
    end
    local h = deserialize(f:read("*a"))
    h.callback = callback
    updating_tab_titles = true
    funcs.safe_del_tab_var(0, 'azul_title_placeholders')
    L.restore_tab_history(h, 1, 1, nil, 0)
    f:close()
end

M.set_win_id = function(id)
    local t = L.term_by_buf_id(vim.fn.bufnr('%'))
    t.azul_win_id = id
end

M.set_tab_variable = function(key, value)
    vim.t[key] = value
end

M.set_cmd = function(cmd)
    local t = L.term_by_buf_id(vim.fn.bufnr('%'))
    t.azul_cmd = cmd
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

local snapshotEquals = function(s1, s2)
    local i = 1;
    while i <= #s1 do
        if s1[i] ~= s2[i] then
            return false
        end
        i = i + 1
    end

    return true
end

local function diff(s1, s2)
    if snapshotEquals(s1, s2) then
        local result = {}
        local j = #s1 + 1
        while j <= #s2 do
            table.insert(result, s2[j])
            j = j + 1
        end

        return result
    end

    if #s1 == 0 then
        return s2
    end

    table.remove(s1, 0)
    return diff(s1, s2)
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

M.on = function(ev, callback)
    local to_add = (type(ev) == 'string' and {ev}) or ev

    for _, e in ipairs(to_add) do
        if not vim.tbl_contains(vim.tbl_keys(events), e) then
            L.error(e .. " event does not exists", nil)
        end

        table.insert(events[e], callback)
    end
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

M.block_input = function()
    trigger_event('AboutToBeBlocked')
    return vim.fn.keytrans(vim.fn.getcharstr())
end

M.user_input = function(opts, callback, force)
    M.suspend()
    vim.fn.timer_start(1, function()
        M.resume()
    end)
    vim.ui.input(opts, function(input)
        if (input ~= nil and input ~= '') or force then
            callback(input)
        end
    end)
end

M.get_file = function(callback)
    M.user_input({prompt = "Select a file:" .. ((M.options.use_dressing and '') or ' '), completion = "file"}, callback);
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
            funcs.safe_del_tab_var(tab_id, 'azul_title_placeholders')
            vim.api.nvim_tabpage_set_var(tab_id, 'azul_tab_title_overriden', result)
        end
        update_tab_titles()
    end, true)
end

M.rename_current_tab = function()
    M.rename_tab(vim.fn.tabpagenr())
end

M.on('AzulStarted', function()
    vim.fn.timer_start(200, update_tab_titles)
end)

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
    vim.api.nvim_command('startinsert')
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

return M
