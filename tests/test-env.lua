local uuid = require('uuid').uuid;
local base_path = '/tmp/azul-' .. uuid
local job = require('plenary.job')
local funcs = require('functions')
local test_running = nil
local azul = require('azul')

local TIMEOUT_BETWEEN_KEYS = 100

local file_copy = function(src, dest)
    local fin = io.open(src, "r")
    if fin == nil then
        error("Could not find " .. src)
    end

    local fout = io.open(dest, "w")
    if fout == nil then
        fin:close()
        error("Could not create " .. dest)
    end
    fout:write(fin:read("*a"))
    fout:close()
end

local feedkeys = function(data, mode, escape)
    local _data = data
    if escape then
        _data = vim.api.nvim_replace_termcodes(data, true, false, true)
    end
    vim.api.nvim_feedkeys(_data, mode or 't', false)
end

local extract_chars = function(s)
    local tag = ''
    local result = {}
    for i = 1, #s do
        local c = s:sub(i, i)
        if c == '<' then
            tag = '<'
        elseif c == '>' then
            tag = tag .. '>'
            table.insert(result, tag)
            tag = ''
        else
            if tag == '' then
                table.insert(result, c)
            else
                tag = tag .. c
            end
        end
    end

    return result
end
local remote_send = function(what)
    job:new({
        command = base_path .. '/bin/azul',
        args = {'-a', uuid, '-c', base_path .. '/config', '-s', what},
    }):sync()
end

local quit = function(msg)
    local file = base_path .. "/last-result-" .. test_running
    if require('files').exists(file) then
        return
    end
    local f = io.open(file, "w")
    f:write(msg)
    f:close()
    vim.fn.timer_start(1, function()
        vim.api.nvim_command('qa!')
    end)
end

local reverse = function(_list)
    local result = {}
    local list = {}
    local i = 1
    while i <= #_list do
        if _list[i] == "" then
            break
        end
        table.insert(list, _list[i])
        i = i + 1
    end
    for j=#list, 1, -1 do
        result[#result+1] = list[j]
    end
    return result
end

local get_lines = function()
    return vim.api.nvim_buf_get_lines(vim.fn.bufnr('%'), 0, -1, false)
end

local single_shot = function(ev, callback)
    azul.on(ev, function(args)
        azul.clear_event(ev, callback)
        callback(args)
    end)
end

L = {}
L.simulate_keys = function(mode, keys, idx, after)
    if idx > #keys then
        if after ~= nil then
            vim.fn.timer_start(1, function()
                after()
            end)
        end
        return
    end
    azul.feedkeys(keys[idx], mode)
    vim.fn.timer_start(TIMEOUT_BETWEEN_KEYS, function()
        L.simulate_keys(mode, keys, idx + 1, after)
    end)
end

local check_trigger_after = function(events, ran)
    if #vim.tbl_keys(events) ~= #vim.tbl_keys(ran) then
        return false
    end

    for ev, count in pairs(events) do
        if ran[ev] == nil or count ~= ran[ev] then
            return false
        end
    end

    return true
end

local wait_events = function(events, after)
    local ran = {}
    local after_ran = false
    for ev, _ in pairs(events or {}) do
        azul.on(ev, function()
            if ran[ev] == nil then
                ran[ev] = 0
            end
            ran[ev] = ran[ev] + 1

            if not check_trigger_after(events, ran) then
                return
            end

            azul.clear_event(ev)
            if after_ran then
                return
            end
            after()
            after_ran = true
        end)
    end
end

return {
    set_env = function(uid, test)
        file_copy("./" .. test .. ".spec.lua", "/tmp/" .. uid .. "/nvim/" .. test .. "lua")
    end,
    assert = function(cond, err)
        if not cond then
            quit(err)
        end
    end,
    done = function()
        quit('passed')
    end,
    feedkeys = feedkeys,
    simulate_keys = function(what, events, after)
        wait_events(events, after)
        L.simulate_keys('t', extract_chars(what), 1, (events == nil and after) or nil)
    end,
    wait_events = wait_events,
    single_shot = single_shot,
    set_test_running = function(which)
        test_running = which
    end,
    reverse = reverse,
    get_current_term_lines = get_lines,
    save_layout = function(name)
        azul.save_layout(base_path .. "/" .. name)
    end,
    get_root = function()
        return base_path
    end,
    restore_layout = function(name)
        azul.restore_layout(base_path .. "/" .. name)
    end
}
