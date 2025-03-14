local mappings = {}
math.randomseed()

local get_sensitive_ls = function(ls)
    if ls == nil then
        return ls
    end
    local p = '^(<[amsc])(.*)$'
    local p1, p2 = (ls .. ""):lower():match(p)
    if p1 == nil then
        return ls
    end
    return p1:lower() .. p2
end

local find = function(callback, table)
    local result = vim.tbl_filter(callback, table)
    if #result == 0 then
        return nil
    end

    return result[1]
end

local find_map = function(which, mode)
    return find(function(m) return m.lhs == which end, vim.api.nvim_get_keymap(mode))
end

local log = function(msg, file)
    if file == nil then
        file = "/tmp/azul-log"
    end
    local f = io.open(file, "a+")
    if f == nil then
        return
    end
    f:write(msg)
    f:write("\n")
    f:close()
end

local safe_get_tab_var = function(tab, name)
    local safe, result = pcall(function() return vim.api.nvim_tabpage_get_var(tab, name) end)
    if not safe then
        return nil
    end

    return result
end

local safe_get_buf_var = function(buf, name)
    local safe, result = pcall(function() return vim.api.nvim_buf_get_var(buf, name) end)
    if not safe then
        return nil
    end

    return result
end

local safe_del_buf_var = function(buf, name)
    if safe_get_buf_var(buf, name) ~= nil then
        vim.api.nvim_buf_del_var(buf, name)
    end
end

local safe_del_tab_var = function(tab, name)
    if safe_get_tab_var(tab, name) ~= nil then
        vim.api.nvim_tabpage_del_var(tab, name)
    end
end

local restore_map = function(mode, which, map)
    vim.api.nvim_set_keymap(mode, which, map.rhs or '', {
        nowait = map.nowait, silent = map.silent, expr = map.expr,
        unique = map.unique, callback = map.callback or nil,
        noremap = map.noremap, desc = map.desc,
    })
end

local save_current_mapping = function(key, shortcut, mode)
    mappings[key] = find_map(shortcut, mode)
end

local restore_previous_mapping = function(key, shortcut, mode)
    pcall(function()
        vim.api.nvim_del_keymap(mode, shortcut)
    end)
    if mappings[key] ~= nil then
        restore_map(mode, shortcut, mappings[key])
    end
end

local map_by_action = function(mode, action, mappings)
    return vim.tbl_filter(function(m) return m.m == mode and ((m.options or {}).action or '') == action end, mappings)
end

local current_float_group = function()
    return vim.t.float_group or 'default' -- we can set on a tab the t:float_group variable and
                                          -- then all the floats on that tab
                                          -- will be assigned to the t:float_group group
end

local regexp_group = function(s, p, idx)
    if string.match(s, p) == nil then
        return nil
    end
    local i = 1
    for g in string.gmatch(s, p) do
        if i == idx then
            return g
        end
        i = i + 1
    end

    return nil
end

local function uuid()
    local random = math.random
    local template ='xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'
    return string.gsub(template, '[xy]', function (c)
        local v = (c == 'x') and random(0, 0xf) or random(8, 0xb)
        return string.format('%x', v)
    end) .. ''
end

local join = function(t, delimiter)
    local result = ''
    for i, s in ipairs(t) do
        if i > 1 then
            result = result .. delimiter
        end
        result = result .. s
    end
    return result
end

local remote_command = function(connection)
    local p = '([a-z]+)://([^@]+)@?(.*)$'
    if not string.match(connection, p) then
        return nil
    end
    local proto, bin, host = string.gmatch(connection, p)()
    log("FOUND " .. vim.inspect(proto) .. " AND " .. vim.inspect(bin) .. " AND " .. vim.inspect(host))
    local cmd = ''
    if proto == 'azul' then
        cmd = bin .. ' -a ' .. uuid() .. ' -r'
    elseif proto == 'dtach' then
        cmd = bin .. ' -A ' .. uuid() .. ' ' .. vim.o.shell
    elseif proto == 'abduco' then
        cmd = bin .. ' -A ' .. uuid()
    end
    if host ~= '' and host ~= nil then
        return 'ssh ' .. host .. " -t '" .. cmd .. "'"
    end
    return cmd
end

return {
    remote_command = remote_command,
    get_sensitive_ls = get_sensitive_ls,
    find = find,
    uuid = uuid,
    log = log,
    join = join,
    safe_get_buf_var = safe_get_buf_var,
    safe_del_buf_var = safe_del_buf_var,
    safe_get_tab_var = safe_get_tab_var,
    safe_del_tab_var = safe_del_tab_var,
    find_map = find_map,
    restore_map = restore_map,
    save_current_mapping = save_current_mapping,
    restore_previous_mapping = restore_previous_mapping,
    map_by_action = map_by_action,
    current_float_group = current_float_group,
    regexp_group = regexp_group,
}
