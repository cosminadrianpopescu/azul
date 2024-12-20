local uuid = require('uuid').uuid;
local base_path = '/tmp/azul-' .. uuid
local job = require('plenary.job')

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

local quit = function(msg)
    local f = io.open(base_path .. "/last-result", "w")
    f:write(msg)
    f:close()
    vim.api.nvim_command('qa!')
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
    simulate_keys = remote_send
}
