local cmd = vim.api.nvim_create_autocmd
local map = vim.api.nvim_set_keymap

local is_suspended = false

local M = {
    --- If set to true, then list all buffers
    list_buffers = false,
}

--- @class terminals
--- @field is_current boolean
--- @field buf number
--- @field win_id number
--- @field term_id number
--- @field title string
--- @field group string
local terminals = {}
local original_size = nil
local chan_input_callback = {}
local chan_buffers = {}

local splits = {}
local mode = nil
local is_nested_session = false
local mode_mappings = {
}
local workflow = 'azul'
local mod = nil
local latest_float = {}
local is_reloading = false
local global_last_status = nil
local global_last_modifier = nil
local quit_on_last = true

local L = {}

local find = function(callback, table)
    local result = vim.tbl_filter(callback, table)
    if #result == 0 then
        return nil
    end

    return result[1]
end

M.is_float = function(t)
    return t and t.win_config and t.win_config['zindex'] ~= nil
end

local has_splits = function(tab_page)
    return #vim.tbl_filter(function(x) return x.tab_page == tab_page end, terminals) > 1
end

local remove_term_buf = function(buf)
    terminals = vim.tbl_filter(function(t) return t.buf ~= buf end, terminals)
    if quit_on_last and (#terminals == 0 or #vim.tbl_filter(function(t) return M.is_float(t) == false end, terminals) == 0) then
        vim.api.nvim_command('quit!')
    end
end

M.debug = function(ev)
    print("EV IS " .. vim.inspect(ev))
    print("WIN IS " .. vim.fn.winnr())
    print("WIN ID IS " .. vim.fn.win_getid(vim.fn.winnr()))
    print("TITLE IS ALREADY" .. vim.b.term_title)
    print("JOB ID IS " .. vim.b.terminal_job_id)
    print("LATEST FLOATS ARE " .. vim.inspect(latest_float))
    print("MAPPINGS ARE" .. vim.inspect(mode_mappings))
    -- print("MODE IS" .. mode)
end

local refresh_tab_page = function(t)
    if M.is_float(t) then
        return
    end
    t.tab_page = vim.api.nvim_tabpage_get_number(vim.api.nvim_win_get_tabpage(t.win_id))
end

local refresh_win_config = function(t)
    t.win_config = vim.api.nvim_win_get_config(t.win_id)
    refresh_tab_page(t)
    if t.win_config['height'] == nil then
        t.win_config.height = vim.api.nvim_win_get_height(t.win_id)
    end
    if t.win_config['width'] == nil then
        t.win_config.width = vim.api.nvim_win_get_width(t.win_id)
    end
end

local refresh_buf = function(buf)
    local t = find(function(t) return t.buf == buf end, terminals)
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

local get_win_var_safe = function(win, var)
    local status, ret = xpcall(vim.api.nvim_win_get_var, function(_) end, win, var);
    if not status then
        return nil
    end
    return ret
end

local close_float = function(float)
    refresh_win_config(float)
    local azul_win_id = get_win_var_safe(float.win_id, 'azul_win_id')
    if azul_win_id ~= nil then
        float.azul_win_id = azul_win_id
    end
    local azul_cmd = get_win_var_safe(float.win_id, 'azul_cmd')
    if azul_cmd ~= nil then
        float.azul_cmd = azul_cmd
    end
    vim.api.nvim_win_close(float.win_id, true)
    float.win_id = nil
end

--- Returns the current selected terminal
---
---@return terminals|nil
M.get_current_terminal = function()
    return find(function(t) return t.is_current end, terminals)
end

--- Hides all the floats
M.hide_floats = function()
    local crt = M.get_current_terminal()
    if crt ~= nil and M.is_float(crt) then
        latest_float[crt.group] = crt
    end

    for _, float in ipairs(get_visible_floatings()) do
        close_float(float)
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

    for _, t in ipairs(terminals) do
        if not M.list_buffers then
            vim.api.nvim_buf_set_option(t.buf, 'buflisted', t.win_id == crt.win_id)
        end
        t.is_current = t.buf == ev.buf
        if t.win_id ~= nil and vim.api.nvim_win_is_valid(t.win_id) then
            vim.api.nvim_win_set_option(t.win_id, 'winhl', 'FloatBorder:')
        end
    end
    local what = (M.is_float(crt) and 'FloatBorder') or 'WinSeparator'
    vim.api.nvim_win_set_option(crt.win_id, 'winhl', what .. ':CurrentFloatSel')
    if workflow == 'emacs' or workflow == 'azul' then
        vim.api.nvim_command('startinsert')
    end
end

local on_chan_input = function(callback, which, chan_id, data)
    local t = find(function(x) return x.term_id == chan_id end, terminals)
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
    if is_reloading then
        return
    end
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
    if not vim.fn.exists('w:azul_win_id') then
        vim.api.nvim_win_set_var(0, 'azul_win_id', os.time())
    end
    if type(start_edit) == 'boolean' and start_edit == false then
        return
    end
    vim.api.nvim_command('startinsert')
end

local OnTermClose = function(ev)
    if is_suspended then
        return
    end
    local t = find(function(t) return t.buf == ev.buf end, terminals)
    remove_term_buf(ev.buf)
    if #terminals == 0 then
        return
    end
    if t ~= nil then
        if find(function(t2) return t2.win_id == t.win_id end, terminals) == nil then
            vim.api.nvim_win_close(t.win_id, true)
        else
            vim.api.nvim_command('bnext')
        end
    end
    vim.api.nvim_buf_delete(ev.buf, {force = true})
    vim.fn.timer_start(1, function()
        ev.buf = vim.fn.bufnr()
        OnEnter(ev)
    end)
end

--- Enters a custom mode. Use this function for changing custom modes
---@param new_mode 'p'|'r'|'s'|'m'|'T'|'n'|'t'
M.enter_mode = function(new_mode)
    L.unmap_all(mode)
    mode = new_mode
    vim.api.nvim_command('doautocmd User MxModeChanged')
    L.remap_all(new_mode)
end

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
            cwd = vim.fn.getcwd(),
        })
        L.current_group = nil
        OnEnter(ev)
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
        if is_suspended or is_nested_session then
            return
        end
        local to = string.gsub(ev.match, '^[^:]+:(.*)', '%1'):sub(1, 1)
        local from = string.gsub(ev.match, '^([^:]+):.*', '%1'):sub(1, 1)
        if to ~= from then
            M.enter_mode(to)
        end
    end
})

cmd({'UiEnter'}, {
    pattern = {'*'}, callback = function(_)
        M.feedkeys('<C-\\><C-n>i', 't')
        -- vim.fn.timer_start(1, function()
        --     M.enter_mode('')
        --     vim.api.nvim_command('startinsert')
        -- end)
    end
})

local restore_float = function(t)
    if t == nil or not vim.api.nvim_buf_is_valid(t.buf) then
        return
    end
    vim.api.nvim_open_win(t.buf, true, t.win_config)
    refresh_buf(t.buf)
    if t.azul_win_id ~= nil then
        vim.w.azul_win_id = t.azul_win_id
    end
    if t.azul_cmd ~= nil then
        vim.w.azul_cmd = t.azul_cmd
    end
end

L.do_show_floats = function(floatings, idx, after_callback)
    if idx > #floatings then
        if after_callback ~= nil then
            after_callback()
        end
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
        vim.api.nvim_open_win(buf, true, opts or {
            width = math.floor(w), height = math.floor(h), col = math.floor(x), row = math.floor(y),
            focusable = true, zindex = 1, border = 'rounded', title = vim.b.term_title, relative = 'editor', style = 'minimal'
        })
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

local clone = function(obj)
    local result = {}
    for k, v in pairs(obj) do
        result[k] = v
    end
    return result
end

M.feedkeys = function(what, mode)
    local codes = vim.api.nvim_replace_termcodes(what, true, false, true)
    vim.api.nvim_feedkeys(codes, mode, false)
end

L.is_vim_mode = function(m)
    return (m:match("^[nvxoitc]") and true) or false
end

local do_set_key_map = function(map_mode, ls, rs, options)
    local pref1 = (workflow == 'azul' and map_mode == 't' and mod) or ''
    -- if L.is_vim_mode(map_mode) then
    --     vim.api.nvim_set_keymap(map_mode, pref1 .. ls .. '', rs .. '', options)
    -- end
    local mappings = vim.tbl_filter(function(m) return m.m == map_mode and m.ls == ls and m.pref == pref1 end, mode_mappings)
    local _mode = (L.is_vim_mode(map_mode) and map_mode) or ((workflow == 'tmux' and 'n') or 't')
    if #mappings == 0 then
        table.insert(mode_mappings, {
            m = map_mode, ls = ls, rs = rs, options = options, pref = pref1, real_mode = _mode
        })
    else
        local x = mappings[1]
        x.m = map_mode
        x.ls = ls
        x.rs = rs
        x.options = options
        x.pref = pref1
        x.real_mode = _mode
    end
end

M.remove_key_map = function(m, ls)
    local pref1 = (workflow == 'azul' and m == 't' and mod) or ''
    mode_mappings = vim.tbl_filter(function(_m) return _m.m ~= m or _m.ls ~= ls or m.pref ~= pref1 end, mode_mappings)
end

L.unmap_all = function(mode)
    local cmds = {}
    local collection = vim.tbl_filter(function(x) return x.m == mode end, mode_mappings)
    for _, m in ipairs(collection) do
        local cmd = m.real_mode .. 'unmap ' .. m.pref .. m.ls
        -- print(cmd)
        if vim.tbl_contains(cmds, cmd) == false then
            vim.api.nvim_command(cmd)
            table.insert(cmds, cmd)
        end
    end
end

L.remap_all = function(mode)
    local collection = vim.tbl_filter(function(x) return x.m == mode end, mode_mappings)
    for _, m in ipairs(collection) do
        vim.api.nvim_set_keymap(m.real_mode, m.pref .. m.ls, m.rs, m.options)
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
    local t = find(function(t) return t.buf == buf end, terminals)
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

M.select_float = function(buf)
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

M.select_next_term = function(dir, group)
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
        M.select_float(found.buf)
    end)
end

M.current_mode = function()
    return mode
end

M.reload_config = function()
    M.set_workflow(workflow, mod)
    local terms = terminals
    is_reloading = true
    -- vim.cmd('source ' .. os.getenv('AZUL_PREFIX') .. '/nvim/lua/azul.lua')
    vim.cmd('source ' .. os.getenv('AZUL_PREFIX') .. '/nvim/init.lua')
    -- dofile(os.getenv('AZUL_PREFIX') .. '/nvim/lua/azul.lua')
    -- dofile(os.getenv('AZUL_PREFIX') .. '/nvim/init.lua')
    is_reloading = false
    terminals = terms
end

M.send_to_buf = function(buf, data, escape)
    local t = find(function(t) return t.buf == buf end, terminals)
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

M.get_tab_terminal = function(n)
    if n == vim.api.nvim_tabpage_get_number(0) then
        return M.get_current_terminal()
    end

    return find(function(t) return t.buf == vim.api.nvim_tabpage_get_var(n, 'current_buffer') end, terminals)
end

M.split = function(dir)
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

    vim.fn.timer_start(1, function()
        vim.api.nvim_command(cmd)
        vim.o.splitright = splitright
        vim.o.splitbelow = splitbelow
    end)
end

M.toggle_nested_mode = function(delim)
    local _delim = delim or '<C-\\><C-s>'
    is_nested_session = not is_nested_session
    vim.api.nvim_command('doautocmd User MxToggleNestedMode')
    if is_nested_session then
        global_last_status = vim.o.laststatus
        global_last_modifier = mod
        vim.o.laststatus = 0
        M.set_workflow(workflow, '')
        map('t', _delim, '', {
            callback = function()
                M.toggle_nested_mode(delim)
            end
        })
        L.unmap_all(mode)
        vim.api.nvim_command('startinsert')
        return
    end

    vim.o.laststatus = global_last_status
    vim.api.nvim_command('tunmap ' .. _delim)
    M.set_workflow(workflow, global_last_modifier)
    L.remap_all(mode)
end

M.position_current_float = function(where)
    local conf = vim.api.nvim_win_get_config(0)

    if where == "top" then
        conf.row = 0
    elseif where == "right" then
        conf.col = fix_coord(conf.width, conf.width, vim.o.columns) + 3
    elseif where == "bottom" then
        conf.row = fix_coord(conf.height, conf.height, vim.o.lines - 1) + 2
    elseif where == "left" then
        conf.col = 0
    end
    vim.api.nvim_win_set_config(0, conf)
end

M.redraw = function()
    local lines = vim.o.lines
    vim.api.nvim_command('set lines=' .. (lines - 1))
    vim.fn.timer_start(100, function()
        vim.api.nvim_command('set lines=' .. lines)
    end)
end

M.is_nested_session = function()
    return is_nested_session
end

M.set_workflow = function(w, m)
    if mod ~= nil and mod ~= '' and workflow == 'tmux' then
        vim.api.nvim_command('tunmap ' .. mod)
    end
    mod = m or '<C-s>'
    workflow = w
    if m ~= '' and workflow == 'tmux' then
        map('t', mod, '<C-\\><C-n>', {})
    end
end

M.suspend = function()
    is_suspended = true
end

M.resume = function()
    is_suspended = false
end

M.save_splits = function()
    splits = {}
    for _, t in ipairs(vim.tbl_filter(function(x) return not M.is_float(x) end, terminals)) do
        table.insert(splits, {
            win_id = t.win_id,
            height = vim.api.nvim_win_get_height(t.win_id),
            width = vim.api.nvim_win_get_width(t.win_id),
        })
    end
end

M.restore_splits = function()
    for _, s in ipairs(splits) do
        if vim.api.nvim_win_is_valid(s.win_id) then
            vim.api.nvim_win_set_height(s.win_id, s.height)
            vim.api.nvim_win_set_width(s.win_id, s.width)
        end
    end
end

local get_visible_splits = function()
    local tab = vim.api.nvim_get_current_tabpage()
    return vim.tbl_filter(function(x)
        return not M.is_float(x)
            and vim.api.nvim_win_get_tabpage(x.win_id) == tab
            and (vim.api.nvim_win_get_width(x.win_id) < vim.o.columns or vim.api.nvim_win_get_height(x.win_id) < vim.o.lines)
    end, terminals)
end

M.resize = function(w, h)
    M.suspend()
    local is_restore = (original_size ~= nil and ((original_size.w == w and original_size.h == h) or (h == 0 and w == 0)))
    if is_restore and h == 0 and w == 0 then
        h = original_size.h
        w = original_size.w
    end
    if not is_restore and original_size ~= nil then
        M.resize(original_size.w, original_size.h)
    end
    local ws = w / vim.o.columns
    local hs = h / vim.o.lines
    local collection = get_visible_splits()
    local buf = nil
    for _, t in ipairs(collection) do
        if buf == nil then
            vim.api.nvim_command("e ./tmp")
            buf = vim.fn.bufnr()
        else
            vim.api.nvim_win_set_buf(t.win_id, buf)
        end
        if not is_restore then
            t._w = vim.api.nvim_win_get_width(t.win_id)
            t._h = vim.api.nvim_win_get_height(t.win_id)
        end
    end

    local lines = vim.o.lines
    local cols = vim.o.columns
    vim.o.lines = h
    vim.o.columns = w

    for _, t in ipairs(collection) do
        if not is_restore then
            vim.api.nvim_win_set_height(t.win_id, math.ceil(t._h * hs) + 1)
            vim.api.nvim_win_set_width(t.win_id, math.ceil(t._w * ws) + 1)
        elseif t._h ~= nil and t._w ~= nil then
            vim.api.nvim_win_set_height(t.win_id, t._h)
            vim.api.nvim_win_set_width(t.win_id, t._w)
        end
    end

    for _, t in ipairs(collection) do
        vim.api.nvim_win_set_buf(t.win_id, t.buf)
    end

    if buf ~=nil and vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
        vim.api.nvim_command('bwipeout ' .. buf)
    end
    if not is_restore then
        original_size = {w = cols, h = lines}
    end
    M.resume()
end

--- Disconnects the current session.
M.disconnect = function()
    for _, ui in ipairs(vim.tbl_filter(function(x) return not x.stdout_tty and x.chan end, vim.api.nvim_list_uis())) do
        vim.fn.chanclose(ui.chan)
    end
end

--- Registers a callback that will be called everytime a new line is 
--- dumped on a terminal. The callback should have the signature:
---
--- --- @param mode 'err' | 'out' (the line was emitted on std_err or std_out)
--- --- @param line a string containing the new line
--- --- @param term The terminal that dumped the line.
--- function callback(mode, line, term)
--- end
---
---@return terminals|nil
M.register_on_chan_line = function(callback)
    table.insert(chan_input_callback, callback)
end

local serialize = function(var)
    return string.gsub(string.gsub(vim.inspect(var), "\n", "\\n"), "'", "\\'")
end

local deserialize = function(var)
    return loadstring("return " .. string.gsub(var, "\\n", "\n"))()
end

local get_splits_restore_lines = function(crt, lines)
    local result = {}
    table.insert(result, 0)
    while lines[crt] ~= 'argglobal' do
        table.insert(result, lines[crt])
        crt = crt + 1
    end

    while crt <= #lines and lines[crt] ~= 'tabnext' do
        crt = crt + 1
    end

    result[1] = crt
    return result
end

local term_by_job_pid = function(pid)
    return find(function(t) return vim.api.nvim_buf_get_var(t.buf, 'terminal_job_pid') == 1 * pid end, terminals)
end

L.term_by_buf_id = function(id)
    return find(function(t) return t.buf == 1 * id end, terminals)
end

local get_tab_windows = function(tab)
    return vim.tbl_filter(function(x) return vim.api.nvim_win_get_tabpage(x) == tab end, vim.api.nvim_list_wins())
end

local select_dir = function(t, which)
    local wins = get_tab_windows(t)
    if #wins <= 1 then
        return
    end

    local prev_id = -1
    while prev_id ~= vim.fn.win_getid() do
        prev_id = vim.fn.win_getid()
        vim.api.nvim_command('wincmd ' .. which)
    end
end

M.save_layout = function(where)
    for _, t in ipairs(terminals) do
        refresh_tab_page(t)
    end

    M.hide_floats()
    M.suspend()
    vim.api.nvim_command('tabrewind')
    for _, t in ipairs(vim.api.nvim_list_tabpages()) do
        select_dir(t, 'h')
        select_dir(t, 'k')
        vim.api.nvim_command('tabnext')
    end
    M.resume()

    local opts = vim.o.sessionoptions
    vim.o.sessionoptions = 'tabpages,terminal,winsize'
    vim.api.nvim_command('mksession! ' .. where)

    local f = io.open(where, "r")
    local sess = ''
    local line = f:read('*L')
    local processed = {}
    while line do
        if vim.fn.match(line, '\\v^badd') == 0 then
            goto continuewhile
        end
        if vim.fn.match(line, 'term:\\/\\/') == -1 then
            sess = sess .. line
        else
            local pid = vim.fn.substitute(line, '\\v^.*term:\\/\\/[^:]+\\/([0-9]+):.*$', '\\1', 'gi')
            local t = term_by_job_pid(pid)
            if find(function(x) return x == pid end, processed) == nil and t ~= nil and t.win_id ~= nil then
                if get_win_var_safe(t.win_id, 'azul_win_id') then
                    sess = sess .. "let w:azul_win_id = '" .. string.gsub(vim.api.nvim_win_get_var(t.win_id, 'azul_win_id'), "'", "\\'") .. "'\n"
                end
                if get_win_var_safe(t.win_id, 'azul_cmd') ~= nil then
                    sess = sess .. "let w:azul_cmd = '" .. string.gsub(get_win_var_safe(t.win_id, 'azul_cmd'), "'", "\\'") .. "'\n"
                end
                table.insert(processed, pid)
            end
        end
        ::continuewhile::
        line = f:read('*L')
    end
    sess = sess .. "let g:azul_floats = '" .. serialize(vim.tbl_filter(function(x) return M.is_float(x) end, terminals)) .. "'"
    f:close()
    f = io.open(where, "w")
    f:write(sess)
    f:close()
    vim.o.sessionoptions = opts
end

local call_with_last_term = function(callback)
    local last_t = find(function(x) return x.buf == vim.fn.bufnr() end, terminals)
    if last_t == nil then
        return
    end
    if last_t ~= nil and callback ~= nil then
        callback(last_t, vim.w.azul_win_id)
    end
    if vim.w.azul_cmd ~= nil then
        M.send_to_buf(last_t.buf, vim.w.azul_cmd .. '<cr>', true)
    end
end

--- Restores a saved layout
---
--- @param where string The saved file location
--- @param callback function(t) callback called after each terminal is restores. 
---                             The t is the just opened terminal
M.restore_layout = function(where, callback)
    quit_on_last = false
    local floats = get_all_floats()
    if #floats > 0 then
        M.hide_floats()
        M.suspend()
        for _, f in ipairs(floats) do
            vim.fn.chanclose(f.term_id)
        end
        terminals = vim.tbl_filter(function(t) return not M.is_float(t) end, terminals)
        M.resume()
    end
    for _, t in ipairs(terminals) do
        vim.fn.chanclose(t.term_id)
    end
    -- Wait that all the terminals are closed.
    while #terminals > 0 do
        vim.fn.timer_start(50, function()
            M.restore_layout(where, callback)
        end)
        return
    end
    M.feedkeys("i<cr>", "t")
    vim.fn.timer_start(1, function()
        M.suspend()
        vim.api.nvim_command('source ' .. where)
        vim.api.nvim_command('tabrewind')
        M.resume()
        for _, t in ipairs(vim.api.nvim_list_tabpages()) do
            local wins = get_tab_windows(t)
            for _, w in ipairs(wins) do
                while vim.fn.win_getid() ~= w do
                    vim.api.nvim_command('wincmd w')
                end
                -- vim.api.nvim_command('terminal')
                vim.api.nvim_command('enew')
                M.open(true)
                OnEnter({buf = vim.fn.bufnr()})
                call_with_last_term(callback)
            end
            vim.api.nvim_command("tabnext")
        end
        quit_on_last = true
        local floats = deserialize(vim.g.azul_floats)
        for _, f in ipairs(floats) do
            -- M.open_float(f.group, f.win_config)
            local buf = vim.api.nvim_create_buf(true, false)
            local w = vim.api.nvim_open_win(buf, true, f.win_config)
            L.current_group = f.group or 'default'
            M.open(false)
            if f.azul_cmd then
                vim.api.nvim_win_set_var(w, 'azul_cmd', f.azul_cmd)
            end
            if f.azul_win_id then
                vim.api.nvim_win_set_var(w, 'azul_win_id', f.azul_win_id)
            end
            call_with_last_term(callback)
        end
    end)
end

return M
