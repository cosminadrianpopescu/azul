local cmd = vim.api.nvim_create_autocmd
local map = vim.api.nvim_set_keymap

local terminals = {}
local shell = '/bin/bash'
local mode = 'n'
local floats_visible = false

local hiding = false
local term_close_enabled = true

local find = function(callback, table)
    local result = vim.tbl_filter(callback, table)
    if #result == 0 then
        return nil
    end

    return result[1]
end

local is_float = function(t)
    return t.win_config and t.win_config['zindex'] ~= nil
end

local remove_term_buf = function(buf)
    terminals = vim.tbl_filter(function(t) return t.buf ~= buf end, terminals)
    if #terminals == 0 or #vim.tbl_filter(function(t) return is_float(t) == false end, terminals) == 0 then
        print("WOULD QUIT")
        -- vim.api.nvim_command('cunabbrev quit')
        -- vim.api.nvim_command('quit!')
    end
end

local tmp = function(ev)
    print("EV IS " .. vim.inspect(ev))
    print("WIN IS " .. vim.fn.winnr())
    print("WIN ID IS " .. vim.fn.win_getid(vim.fn.winnr()))
    print("TITLE IS ALREADY" .. vim.b.term_title)
    print("JOB ID IS " .. vim.b.terminal_job_id)
end

local update_current = function(buf)
    for _, term in ipairs(terminals) do
        term.is_current = false
    end

    local t = find(function(t) return t.buf == buf end, terminals)
    if t == nil then
        return nil
    end
    t.is_current = true
    t.title = vim.b.term_title
    t.win_id = vim.fn.win_getid(vim.fn.winnr())
    t.win_config = vim.api.nvim_win_get_config(t.win_id)
    return t
end

local hide_floats = function()
    local floatings = vim.tbl_filter(function(t) return is_float(t) and t.win_id ~= nil end, terminals)
    print("FOUND " .. vim.inspect(floatings))

    for _, float in ipairs(floatings) do
        vim.api.nvim_win_close(float.win_id, true)
        float.win_id = nil
    end
end

local OnEnter = function(ev)
    local crt = update_current(ev.buf)
    if crt == nil then
        return
    end

    floats_visible = is_float(crt)
    print("FLOAT VISIBLE " .. vim.inspect(floats_visible))
    tmp(ev)

    for _, t in ipairs(terminals) do
        vim.api.nvim_buf_set_option(t.buf, 'buflisted', is_float(t) == floats_visible)
    end

    if is_float(crt) == false then
        hide_floats()
    end
end

local open = function(start_edit)
    vim.api.nvim_command('terminal')
    if type(start_edit) == 'boolean' and start_edit == false then
        return
    end
    vim.api.nvim_command('startinsert')
end

cmd('TermOpen',{
    pattern = "*", callback = function(ev)
        table.insert(terminals, {
            is_current = false,
            buf = ev.buf,
            win_id = vim.fn.win_getid(vim.fn.winnr()),
            title = vim.b.term_title,
        })
        OnEnter(ev)
    end
})

cmd('TermClose', {
    pattern = "*", callback = function(ev)
        remove_term_buf(ev.buf)
    end
})

cmd('TermEnter', {
    pattern = "*", callback = OnEnter
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

-- cmd('TermLeave', {
--     pattern = "*", callback = tmp
-- })

-- cmd('WinClosed', {
--     pattern = "term://*", callback = function(ev)
--         print("BEGIN WINCLOSED" .. vim.inspect(ev))
--         term_close_enabled = false
--         local id = vim.fn.win_getid(vim.fn.winnr())
--         local to_close = vim.tbl_filter(function(t) return t.win_id == id end, terminals)
--         if #to_close == 0 then
--             print("END WINCLOSED PREM")
--             term_close_enabled = true
--             return
--         end
--         for _, t in ipairs(to_close) do
--             remove_term_buf(t.buf)
--             vim.api.nvim_command('bdelete! ' .. t.buf)
--         end
--         term_close_enabled = true
--         print("END WINCLOSED")
--     end
-- })

local show_floats = function()
    local floatings = vim.tbl_filter(function(t) return t['win_config'] ~= nil and t.win_config['zindex'] ~= nil end, terminals)
    for _, t in ipairs(floatings) do
        vim.api.nvim_open_win(t.buf, true, t.win_config)
    end
end

local open_float = function(title, opts)
    -- show_floats()
    local buf = vim.api.nvim_create_buf(true, false)
    vim.api.nvim_open_win(buf, true, opts or {
        width = 80, height = 24, row = 30, col = 30, focusable = true, zindex = 1, border = 'rounded', title = title or vim.b.term_title or title, relative = 'editor', style = 'minimal'
    })
    -- open(false)
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
    show_terminals = show_terminals,
    set_key_map = set_key_map,
    enter_pane_mode = enter_pane_mode,
    exit_pane_mode = exit_pane_mode,
    hide_floats = hide_floats,
    show_floats = show_floats,
    open = open,
}
