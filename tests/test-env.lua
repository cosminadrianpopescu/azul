local uuid = require('uuid').uuid;
local base_path = '/tmp/azul-' .. uuid
local job = require('plenary.job')
local test_running = nil
local azul = require('azul')

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

local remote_send = function(what)
    -- vim.fn.jobstart(base_path .. '/bin/azul -a ' .. uuid .. ' -c ' .. base_path .. '/config -s "' .. what .. '"', {
    --     on_exit = function()
    --         if callback == nil then
    --             return
    --         end
    --         callback()
    --     end
    -- })
    job:new({
        command = base_path .. '/bin/azul',
        args = {'-a', uuid, '-c', base_path .. '/config', '-s', what},
    }):sync()
end

local log = function(msg, file)
    local f = io.open(file, "a+")
    if f == nil then
        return
    end
    f:write(msg)
    f:write("\n")
    f:close()
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
    simulate_keys = remote_send,
    log = log,
    single_shot = function(ev, callback)
        azul.on(ev, function(args)
            azul.clear_event(ev, callback)
            callback(args)
        end)
    end,
    set_test_running = function(which)
        test_running = which
    end,
    reverse = reverse,
    get_current_term_lines = get_lines,
    save_layout = function(name)
        azul.save_layout(base_path .. "/" .. name)
    end,
    restore_layout = function(name)
        azul.restore_layout(base_path .. "/" .. name)
    end
}
