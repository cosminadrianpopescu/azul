local cmd = vim.api.nvim_create_autocmd
local map = vim.api.nvim_set_keymap

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

local mode = 'n'
local is_nested_session = false
local mode_mappings = {
}
local workflow = 'azul'
local mod = nil
local mod2 = '<C-y><C-x>'
local latest_float = {}
local is_reloading = false
local global_last_status = nil
local global_last_modifier = nil

local L = {}

local find = function(callback, table)
    local result = vim.tbl_filter(callback, table)
    if #result == 0 then
        return nil
    end

    return result[1]
end

local is_float = function(t)
    return t and t.win_config and t.win_config['zindex'] ~= nil
end

local remove_term_buf = function(buf)
    terminals = vim.tbl_filter(function(t) return t.buf ~= buf end, terminals)
    if #terminals == 0 or #vim.tbl_filter(function(t) return is_float(t) == false end, terminals) == 0 then
        -- print("WOULD QUIT")
        -- vim.api.nvim_command('cunabbrev quit')
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

local refresh_buf = function(buf)
    local t = find(function(t) return t.buf == buf end, terminals)
    if t == nil then
        return nil
    end
    t.win_id = vim.fn.win_getid(vim.fn.winnr())
    t.win_config = vim.api.nvim_win_get_config(t.win_id)
    return t
end

local get_visible_floatings = function()
    return vim.tbl_filter(function(t) return is_float(t) and t.win_id ~= nil end, terminals)
end

local close_float = function(float)
    float.win_config = vim.api.nvim_win_get_config(float.win_id)
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
    if crt ~= nil and is_float(crt) then
        latest_float[crt.group] = crt
    end

    for _, float in ipairs(get_visible_floatings()) do
        close_float(float)
    end
end

local OnEnter = function(ev)
    local crt = refresh_buf(ev.buf)
    if crt == nil then
        return
    end

    if is_float(crt) == false then
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
    local what = (is_float(crt) and 'FloatBorder') or 'WinSeparator'
    vim.api.nvim_win_set_option(crt.win_id, 'winhl', what .. ':CurrentFloatSel')
    if workflow == 'emacs' or workflow == 'azul' then
        vim.api.nvim_command('startinsert')
    end
end

--- Opens a new terminal in the current window
---
---@param start_edit boolean If true, then start editing automatically (default true)
M.open = function(start_edit)
    if is_reloading then
        return
    end
    vim.api.nvim_command('terminal')
    if type(start_edit) == 'boolean' and start_edit == false then
        return
    end
    vim.api.nvim_command('startinsert')
end

local OnTermClose = function(ev)
    local t = find(function(t) return t.buf == ev.buf end, terminals)
    remove_term_buf(ev.buf)
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
---@param m 'p'|'r'|'s'|'m'
M.enter_mode = function(m)
    mode = m
    vim.api.nvim_command('doautocmd User MxModeChanged')
end

cmd('TermOpen',{
    pattern = "*", callback = function(ev)
        table.insert(terminals, {
            is_current = false,
            buf = ev.buf,
            win_id = vim.fn.win_getid(vim.fn.winnr()),
            term_id = vim.b.terminal_job_id,
            group = L.current_group
        })
        L.current_group = nil
        OnEnter(ev)
    end
})

cmd('TermClose', {
    pattern = "*", callback = OnTermClose
})

cmd('TermEnter', {
    pattern = "*", callback = OnEnter
})

cmd({'WinEnter'}, {
    pattern = "term://*", callback = function(ev)
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
        vim.api.nvim_tabpage_set_var(0, 'current_buffer', vim.fn.bufnr())
    end
})

cmd({'WinNew'}, {
    pattern = "term://*", callback = function()
        vim.fn.timer_start(1, function()
            M.open(false)
        end)
    end
})

cmd({'ModeChanged'}, {
    pattern = {'*'}, callback = function(ev)
        local to = string.gsub(ev.match, '^[^:]+:(.*)', '%1'):sub(1, 1)
        local from = string.gsub(ev.match, '^([^:]+):.*', '%1'):sub(1, 1)
        -- print(from .. ":" .. to)
        if to ~= from then
            M.enter_mode(to)
        end
    end
})

local restore_float = function(t)
    if t == nil or not vim.api.nvim_buf_is_valid(t.buf) then
        return
    end
    vim.api.nvim_open_win(t.buf, true, t.win_config)
    refresh_buf(t.buf)
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
    local floatings = vim.tbl_filter(function(t) return is_float(t) and t ~= latest_float[g] and t.group == g end, terminals)
    table.sort(floatings, function(a, b) return a.last_access < b.last_access end)
    if latest_float[g] ~= nil then
        floatings[#floatings + 1] = latest_float[g]
    end
    L.do_show_floats(floatings, 1, after_callback)
end

M.are_floats_hidden = function(group)
    local floatings = vim.tbl_filter(function(t) return is_float(t) and t.group ==(group or 'default') end, terminals)
    if #floatings == 0 then
        return true
    end
    return #vim.tbl_filter(function(t) return t.win_id == nil and t.group == (group or 'default') end, floatings) > 0
end

--- Opens a new float
---@param opts table the options of the new window (@ses vim.api.nvim_open_win)
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
    if M.are_floats_hidden(group) then
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

local map_callback_execute = function(what, mode)
    vim.fn.timer_start(1, function()
        if type(what) == "function" then
            what()
        else
            M.feedkeys(what, mode)
        end
    end)
end

-- local get_pref2 = function(pref1)
--     if pref1 ~= '' or workflow == 'emacs' then
--         return mod2
--     end
-- 
--     if workflow == 'zellij' and (mode == 'p' or mode == 'r' or mode == 's' or mode == 'm') then
--         return mod2
--     end
-- 
--     return ''
-- end

local do_set_key_map = function(m, ls, rs, options)
    local options2 = clone(options)
    local pref1 = (workflow == 'azul' and m == 't' and mod) or ''
    options2.callback = function()
        local mappings = vim.tbl_filter(function(m) return m.m == mode and m.ls == ls end, mode_mappings)
        if #mappings == 0 then
            return pref1 .. ls
        end
        local mapping = mappings[1]
        map_callback_execute(mapping.options.callback or mapping.rs, 'n')
        return 0x0 .. '<bs>'
    end
    options2.replace_keycodes = true
    options2.expr = true
    local _mode = (workflow == 'tmux' and 'n') or 't'
    map(_mode, pref1 .. ls, '', options2)
    table.insert(mode_mappings, {
        m = m, ls = ls, rs = rs, options = options, pref = pref1, real_mode = _mode
    })
end

M.remove_key_map = function(m, ls)
    mode_mappings = vim.tbl_filter(function(_m) return _m.m ~= m or _m.ls ~= ls end, mode_mappings)
end

local unmap_all = function()
    local cmds = {}
    for _, m in ipairs(mode_mappings) do
        local cmd = m.real_mode .. 'unmap ' .. m.pref .. m.ls
        if vim.tbl_contains(cmds, cmd) == false then
            vim.api.nvim_command(cmd)
            table.insert(cmds, cmd)
        end
    end
end

local remap_all = function()
    local mm = mode_mappings
    mode_mappings = {}
    for _, m in ipairs(mm) do
        do_set_key_map(m.m, m.ls, m.rs, m.options)
    end
end

-- local do_set_key_map = function(m, ls, rs, options)
--     if mode_mappings[m] ~= nil then
--         mode_mappings[m][ls] = options.callback or rs
--     end
--     local options2 = clone(options)
-- 
--     local pref1 = (workflow == 'azul' and m == 't' and mod) or ''
-- 
--     options2.callback = function()
--         local pref2 = get_pref2(pref1)
--         local mappings = mode_mappings[mode]
--         if is_nested_session then
--             return pref1 .. ls
--         end
--         if mappings ~= nil then
--             map_callback_execute(mappings[ls], (workflow == 'tmux' and 'n') or 't')
--             return ''
--         end
-- 
--         return pref2 .. ls
--     end
-- 
--     options2.expr = true
--     options2.replace_keycodes = true
-- 
--     local _mode = (workflow == 'tmux' and 'n') or 't'
-- 
--     if mode_mappings[m] == nil then
--         _mode = m
--     end
-- 
--     print("MAPPING" .. pref1 .. ", " .. mod2 .. ", " .. ls)
--     map(_mode, pref1 .. ls, '', options2)
--     map(_mode, mod2 .. ls, '', options)
-- end

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
    local row, col = conf["row"][false], conf["col"][false]
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
    for _, t in ipairs(vim.tbl_filter(function(t) return t ~= crt and is_float(t) and t.win_id ~= nil end, terminals)) do
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
    local cmd = 'split'
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
        unmap_all()
        vim.api.nvim_command('startinsert')
        return
    end

    vim.o.laststatus = global_last_status
    vim.api.nvim_command('tunmap ' .. _delim)
    M.set_workflow(workflow, global_last_modifier)
    remap_all()
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

return M
