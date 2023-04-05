local cmd = vim.api.nvim_create_autocmd
local map = vim.api.nvim_set_keymap

local terminals = {}
local mode = 'n'
local mode_mappings = {
    p = {},
    r = {},
    m = {},
}
local default_mod = '<C-s>'
local mod = default_mod
local latest_float = nil
local is_reloading = false

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

local debug = function(ev)
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

local get_current_terminal = function()
    return find(function(t) return t.is_current end, terminals)
end

local hide_floats = function()
    local crt = get_current_terminal()
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
        hide_floats()
    end
    crt.last_access = os.time(os.date("!*t"))

    for _, t in ipairs(terminals) do
        vim.api.nvim_buf_set_option(t.buf, 'buflisted', t.buf == ev.buf)
        t.is_current = t.buf == ev.buf
        if t.win_id ~= nil then
            vim.api.nvim_win_set_option(t.win_id, 'winhl', 'FloatBorder:')
        end
    end
    vim.api.nvim_win_set_option(crt.win_id, 'winhl', 'FloatBorder:CurrentFloatSel')
end

local open = function(start_edit)
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
        vim.api.nvim_win_close(t.win_id, true)
    end
    vim.api.nvim_buf_delete(ev.buf, {force = true})
    vim.fn.timer_start(1, function()
        ev.buf = vim.fn.bufnr()
        OnEnter(ev)
    end)
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
    pattern = "*", callback = function(ev)
        mode = 't'
        OnEnter(ev)
    end
})

cmd({'WinEnter'}, {
    pattern = "term://*", callback = function(ev)
        vim.fn.timer_start(1, function()
            ev.buf = vim.fn.bufnr()
            if vim.b.terminal_job_id == nil then
                open(false)
            end
            OnEnter(ev)
        end)
    end
})

cmd({'WinNew'}, {
    pattern = "term://*", callback = function(ev)
        vim.fn.timer_start(1, function()
            ev.buf = vim.fn.bufnr()
            open(true)
            OnEnter(ev)
        end)
    end
})

local restore_float = function(t)
    print("RESTORE " .. vim.inspect(t.buf))
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

local show_floats = function()
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
    return #vim.tbl_filter(function(t) return is_float(t) and t.win_id == nil end, terminals) > 0
end

local open_float = function(title, opts)
    if floats_are_hidden() then
        show_floats()
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

local toggle_floats = function()
    if floats_are_hidden() then
        show_floats()
    else
        hide_floats()
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

local set_key_map = function(mode, ls, rs, options)
    local modes = mode
    if type(mode) == "string" then
        modes = {mode}
    end

    for _, m in ipairs(modes) do
        do_set_key_map(m, ls, rs, options)
    end
end

local show_terminals = function()
    return terminals
end

local enter_mode = function(m)
    mode = m
end

local set_modifier = function(m)
    if m ~= nil then
        vim.api.nvim_command('tunmap ' .. mod)
        mod = m
    end
    set_key_map('t', mod, '<C-\\><C-n>', {})
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

local move_current_float = function(dir, inc)
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

local select_float = function(buf)
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

local select_next_float = function(dir)
    if floats_are_hidden() then
        return
    end

    local crt = get_current_terminal()
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
        select_float(found.buf)
    end)
end

local current_mode = function()
    return mode
end

local reload_config = function()
    set_modifier(default_mod)
    local terms = terminals
    is_reloading = true
    -- vim.cmd('source ' .. os.getenv('TMNVIM_PREFIX') .. '/nvim/lua/nvim-multiplexer.lua')
    vim.cmd('source ' .. os.getenv('TMNVIM_PREFIX') .. '/nvim/init.lua')
    -- dofile(os.getenv('TMNVIM_PREFIX') .. '/nvim/lua/nvim-multiplexer.lua')
    -- dofile(os.getenv('TMNVIM_PREFIX') .. '/nvim/init.lua')
    is_reloading = false
    terminals = terms
end

local send_to_buf = function(buf, data)
    local t = find(function(t) return t.buf == buf end, terminals)
    if t == nil then
        return
    end

    vim.api.nvim_chan_send(t.term_id, data)
end

local send_to_current = function(data)
    send_to_buf(vim.fn.bufnr(), data)
end

return {
    open_float = open_float,
    show_terminals = show_terminals,
    set_key_map = set_key_map,
    enter_mode = enter_mode,
    hide_floats = hide_floats,
    show_floats = show_floats,
    open = open,
    toggle_floats = toggle_floats,
    set_modifier = set_modifier,
    move_current_float = move_current_float,
    current_mode = current_mode,
    select_float = select_float,
    debug = debug,
    reload_config = reload_config,
    select_next_float = select_next_float,
    send_to_buf = send_to_buf,
    send_to_current = send_to_current,
}
