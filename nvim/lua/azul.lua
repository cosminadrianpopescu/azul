local cmd = vim.api.nvim_create_autocmd
local map = vim.api.nvim_set_keymap

local M = {
    list_buffers = false,
}

local terminals = {}
local mode = 'n'
local is_nested_session = false
local mode_mappings = {
    p = {},
    r = {},
    m = {},
    s = {},
}
local default_mod = '<C-s>'
local mod = default_mod
local latest_float = nil
local is_reloading = false
local global_last_status = nil

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
    -- print("MAPPINGS ARE" .. vim.inspect(mode_mappings))
    -- print("MODE IS" .. mode)
end

local refresh_buf = function(buf)
    local t = find(function(t) return t.buf == buf end, terminals)
    if t == nil then
        return nil
    end
    t.title = vim.b.term_title
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

M.get_current_terminal = function()
    return find(function(t) return t.is_current end, terminals)
end

M.hide_floats = function()
    local crt = M.get_current_terminal()
    if is_float(crt) then
        latest_float = crt
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
end

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
            title = vim.b.term_title,
        })
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
            M.open(true)
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

Do_show_floats = function(floatings, idx)
    if idx > #floatings then
        return
    end
    restore_float(floatings[idx])
    vim.fn.timer_start(10, function()
        Do_show_floats(floatings, idx + 1)
    end)
end

M.show_floats = function()
    local floatings = vim.tbl_filter(function(t) return is_float(t) and t ~= latest_float end, terminals)
    table.sort(floatings, function(a, b) return a.last_access < b.last_access end)
    floatings[#floatings+1] = latest_float
    Do_show_floats(floatings, 1)
    -- for _, t in ipairs(floatings) do
    --     print("RESTORING " .. vim.inspect(t.buf))
    --     restore_float(t)
    -- end

    -- restore_float(latest_float)
end

local floats_are_hidden = function()
    local floatings = vim.tbl_filter(function(t) return is_float(t) end, terminals)
    if #floatings == 0 then
        return true
    end
    return #vim.tbl_filter(function(t) return t.win_id == nil end, floatings) > 0
end

M.open_float = function(title, opts)
    if floats_are_hidden() then
        M.show_floats()
    end
    local buf = vim.api.nvim_create_buf(true, false)
    local factor = 4
    local w = (vim.o.columns - factor) / 2
    local h = (vim.o.lines - factor) / 2
    local x = (vim.o.columns - w) / 2
    local y = (vim.o.lines - h) / 2
    vim.api.nvim_open_win(buf, true, opts or {
        width = math.floor(w), height = math.floor(h), col = math.floor(x), row = math.floor(y),
        focusable = true, zindex = 1, border = 'rounded', title = title or vim.b.term_title or title, relative = 'editor', style = 'minimal'
    })
end

M.toggle_floats = function()
    if floats_are_hidden() then
        M.show_floats()
    else
        M.hide_floats()
    end
end

local do_set_key_map = function(m, ls, rs, options)
    if find(function(k) return k == m end, vim.tbl_keys(mode_mappings)) == nil then
        map(m, ls, rs, options)
        return
    end

    mode_mappings[m][ls] = options.callback or rs
    local options2 = {}

    for k, v in pairs(options) do
        options2[k] = v
    end

    options2.callback = function()
        local mappings = mode_mappings[mode]
        if mappings == nil or mode_mappings[mode][ls] == nil then
            return ls
        end
        local what = mode_mappings[mode][ls]
        if type(what) == "function" then
            what()
        else
            vim.api.nvim_command(what)
        end

        return ''
    end

    options2.expr = true

    map('n', ls, '', options2)
end

M.set_key_map = function(mode, ls, rs, options)
    local modes = mode
    if type(mode) == "string" then
        modes = {mode}
    end

    for _, m in ipairs(modes) do
        do_set_key_map(m, ls, rs, options)
    end
end

M.get_terminals = function()
    return terminals
end

M.set_modifier = function(m)
    if m ~= nil then
        vim.api.nvim_command('tunmap ' .. mod)
        mod = m
    end
    M.set_key_map('t', mod, '<C-\\><C-n>', {})
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
    vim.fn.feedkeys('<c-l>')
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

M.select_next_term = function(dir)
    if floats_are_hidden() then
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
    for _, t in ipairs(vim.tbl_filter(function(t) return t ~= crt and is_float(t) end, terminals)) do
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
    M.set_modifier(default_mod)
    local terms = terminals
    is_reloading = true
    -- vim.cmd('source ' .. os.getenv('AZUL_PREFIX') .. '/nvim/lua/azul.lua')
    vim.cmd('source ' .. os.getenv('AZUL_PREFIX') .. '/nvim/init.lua')
    -- dofile(os.getenv('AZUL_PREFIX') .. '/nvim/lua/azul.lua')
    -- dofile(os.getenv('AZUL_PREFIX') .. '/nvim/init.lua')
    is_reloading = false
    terminals = terms
end

M.send_to_buf = function(buf, data)
    local t = find(function(t) return t.buf == buf end, terminals)
    if t == nil then
        return
    end

    vim.api.nvim_chan_send(t.term_id, data)
end

M.send_to_current = function(data)
    M.send_to_buf(vim.fn.bufnr(), data)
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
    if is_nested_session then
        global_last_status = vim.o.laststatus
        vim.o.laststatus = 0
        vim.api.nvim_command('tunmap ' .. mod)
        M.set_key_map('t', _delim, '', {
            callback = function()
                M.toggle_nested_mode(delim)
            end
        })
        vim.api.nvim_command('startinsert')
        return
    end

    vim.o.laststatus = global_last_status
    vim.api.nvim_command('tunmap ' .. _delim)
    M.set_key_map('t', mod, '<C-\\><C-n>', {})
end

return M
