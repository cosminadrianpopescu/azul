local cmd = vim.api.nvim_create_autocmd
local map = vim.api.nvim_set_keymap

local terminals = {}
local shell = '/bin/bash'
local mode = 'n'

local hiding = false
local term_close_enabled = true

local is_float = function(t)
    if t.win_id == nil and t.win_config == nil then
        return false
    end
    if t.win_id ~= nil then
        local info = vim.api.nvim_win_get_config(t.win_id)
        return info ~= nil and info['zindex'] ~= nil
    end
    return t.win_config['zindex'] ~= nil
end

local remove_term_buf = function(buf)
    terminals = vim.tbl_filter(function(t) return t.buf ~= buf end, terminals)
    if #terminals == 0 or #vim.tbl_filter(function(t) return is_float(t) == false end, terminals) == 0 then
        print("WOULD QUIT")
        -- vim.api.nvim_command('cunabbrev quit')
        -- vim.api.nvim_command('quit!')
    end
end

cmd('TermOpen',{
    pattern = "*", callback = function(ev)
        print("EV IS " .. vim.inspect(ev))
        print("WIN IS " .. vim.fn.winnr())
        print("WIN ID IS " .. vim.fn.win_getid(vim.fn.winnr()))
    end
})

cmd('TermClose', {
    pattern = "term://*", callback = function(ev)
        print("EV IS " .. vim.inspect(ev))
        print("WIN IS " .. vim.fn.winnr())
        print("WIN ID IS " .. vim.fn.win_getid(vim.fn.winnr()))
        if term_close_enabled ~= true then
            return
        end
        remove_term_buf(ev.buf)
    end
})

local find = function(callback, table)
    local result = vim.tbl_filter(callback, table)
    if #result == 0 then
        return nil
    end

    return result[1]
end

local hide_floats = function()
    if hiding then
        return
    end
    local floatings = vim.tbl_filter(function(t) return is_float(t) and t.win_id ~= nil end, terminals)
    hiding = true

    for _, float in ipairs(floatings) do
        float.win_config = vim.api.nvim_win_get_config(float.win_id)
        vim.api.nvim_buf_set_option(float.buf, 'buflisted', false)
        vim.api.nvim_win_close(float.win_id, true)
        float.win_id = nil
    end

    hiding = false
end

cmd('WinClosed', {
    pattern = "term://*", callback = function(ev)
        print("BEGIN WINCLOSED" .. vim.inspect(ev))
        term_close_enabled = false
        local id = vim.fn.win_getid(vim.fn.winnr())
        local to_close = vim.tbl_filter(function(t) return t.win_id == id end, terminals)
        if #to_close == 0 then
            print("END WINCLOSED PREM")
            term_close_enabled = true
            return
        end
        for _, t in ipairs(to_close) do
            remove_term_buf(t.buf)
            vim.api.nvim_command('bdelete! ' .. t.buf)
        end
        term_close_enabled = true
        print("END WINCLOSED")
    end
})

cmd('BufEnter', {
    pattern = "term://*", callback = function(ev)
        print("ENTER BUF" .. vim.inspect(ev))
        for _, t in ipairs(terminals) do
            t.is_current = false
        end
        local t = find(function(t) return t.buf == ev.buf end, terminals)
        print("FOUND T " .. vim.inspect(t))
        if t == nil then
            return
        end
        t.is_current = true
        -- t.win_id = vim.fn.win_getid(vim.fn.winnr())
        if is_float(t) == false then
            hide_floats()
        end
    end
})

local open = function(title, buf)
    vim.env.XDG_CONFIG_HOME = vim.env.NVIM_XDG_CONFIG_HOME
    vim.env.XDG_DATA_HOME = vim.env.NVIM_XDG_DATA_HOME
    local channel = vim.fn.termopen(shell)
    local win = vim.fn.winnr()
    if title then
        vim.api.nvim_command('file ' .. title)
    end
    for _, term in ipairs(terminals) do
        term.is_current = false
    end
    table.insert(terminals, {
        is_current = true,
        buf = buf,
        title = title,
        win_id = vim.fn.win_getid(win),
        channel = channel,
    })
end

local show_floats = function()
    local floatings = vim.tbl_filter(function(t) return t['win_config'] ~= nil end, terminals)
    for _, t in ipairs(floatings) do
        t.win_id = vim.api.nvim_open_win(t.buf, true, t.win_config)
        t.win_config = nil
        vim.api.nvim_buf_set_option(t.buf, 'buflisted', true)
    end
end

local open_float = function(title, opts)
    show_floats()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_open_win(buf, true, opts or {
        width = 80, height = 24, row = 30, col = 30, focusable = true, zindex = 1, border = 'rounded', title = title or vim.b.term_title or title, relative = 'editor', style = 'minimal'
    })
    open(title, buf)
end

local open_normal = function(title)
    local buf = vim.fn.buffer_number()
    if #terminals ~= 0 then
        vim.api.nvim_command('enew')
        buf = vim.fn.buffer_number()
    end
    open(title, buf)
end

local set_key_map = function(m, ls, rs, options)
    if m ~= 'p' then
        map(m, ls, rs, options)
        return
    end

    local real_callback = options.callback or nil

    options.callback = function()
        if mode ~= 'p' then
            return 'l'
        end
        if real_callback then
            real_callback()
        end
        if rs ~= '' then
            vim.api.nvim_command(rs)
        end

        return ''
    end

    options.expr = true

    map('n', ls, '', options)
end

local show_terminals = function()
    return terminals
end

local enter_pane_mode = function()
    mode = 'p'
end

local exit_pane_mode = function()
    mode = 'n'
end

return {
    open_float = open_float,
    open_normal = open_normal,
    show_terminals = show_terminals,
    set_key_map = set_key_map,
    enter_pane_mode = enter_pane_mode,
    exit_pane_mode = exit_pane_mode,
    hide_floats = hide_floats,
    show_floats = show_floats,
}
