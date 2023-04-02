local cmd = vim.api.nvim_create_autocmd
local map = vim.api.nvim_set_keymap

local terminals = {}
local shell = '/bin/bash'
local mode = 'n'
local floats_visible = false
local latest_float = nil
local crt_highlight = 'FloatBorder:ErrorMsg';

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

local tmp = function(ev)
    print("EV IS " .. vim.inspect(ev))
    print("WIN IS " .. vim.fn.winnr())
    print("WIN ID IS " .. vim.fn.win_getid(vim.fn.winnr()))
    print("TITLE IS ALREADY" .. vim.b.term_title)
    print("JOB ID IS " .. vim.b.terminal_job_id)
end

local refresh_buf = function(buf)
    local t = find(function(t) return t.buf == buf end, terminals)
    if t == nil then
        return nil
    end
    t.title = vim.b.term_title
    t.win_id = vim.fn.win_getid(vim.fn.winnr())
    t.win_config = vim.api.nvim_win_get_config(t.win_id)
    if t.winhl ~= nil then
        vim.api.nvim_win_set_option(t.win_id, 'winhl', t.winhl)
    end
    return t
end

local hide_floats = function()
    local floatings = vim.tbl_filter(function(t) return is_float(t) and t.win_id ~= nil end, terminals)

    for _, float in ipairs(floatings) do
        vim.api.nvim_win_close(float.win_id, true)
        float.win_id = nil
    end
end

local OnEnter = function(ev)
    local crt = refresh_buf(ev.buf)
    local old_crt = find(function(t) return t.is_current end, terminals)
    if crt == nil then
        return nil
    end

    if is_float(crt) == false then
        if is_float(old_crt) then
            latest_float = old_crt
        end
        hide_floats()
    end

    for _, t in ipairs(terminals) do
        vim.api.nvim_buf_set_option(t.buf, 'buflisted', t.buf == ev.buf)
        t.is_current = t.buf == ev.buf
    end

    return crt
end

local open = function(start_edit)
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
        local t = OnEnter(ev)
        if t ~= nil then
            t.winhl = vim.api.nvim_win_get_option(t.win_id, 'winhl')
            print("SET " .. vim.api.nvim_win_get_option(t.win_id, 'winhl') .. " for " .. t.win_id)
            vim.api.nvim_win_set_option(t.win_id, 'winhl', crt_highlight)
        end
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

-- cmd({'WinClosed'}, {
--     pattern = "*", callback = function(ev)
--         tmp(ev)
--         vim.api.nvim_buf_delete(ev.buf, {force = true})
--         remove_term_buf(ev.buf)
--     end
-- })

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
    local floatings = vim.tbl_filter(function(t) return is_float(t) and t ~= latest_float end, terminals)
    for _, t in ipairs(floatings) do
        vim.api.nvim_open_win(t.buf, true, t.win_config)
        refresh_buf(t.buf)
    end

    if latest_float ~= nil then
        vim.api.nvim_open_win(latest_float.buf, true, latest_float.win_config)
    end

    latest_float = nil
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
