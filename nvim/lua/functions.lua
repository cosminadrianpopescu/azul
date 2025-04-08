local mappings = {}
math.randomseed()

local compare_shortcuts = function(s1, s2)
    local p1 = '\\v(\\<[^\\>]+\\>)'
    if vim.fn.match(s1, p1) == -1 or vim.fn.match(s2, p1) == -1 then
        return s1 == s2;
    end
    local p2 = '\\v^\\<(.*)\\>$'
    local keys1 = vim.fn.split(vim.fn.substitute(s1, p2, '\\1', 'gi'), '-')
    local keys2 = vim.fn.split(vim.fn.substitute(s2, p2, '\\1', 'gi'), '-')

    if #keys1 ~= #keys2 then
        return false
    end

    local replace_alt = function(keys)
        for _, k in ipairs(vim.tbl_keys(keys)) do
            if string.lower(keys[k]) == 'a' then
                keys[k] = 'm'
            end
        end
    end

    replace_alt(keys1)
    replace_alt(keys2)

    local lowerise = function(keys)
        return vim.tbl_map(function(k) return string.lower(k) end, keys)
    end

    local _keys1 = lowerise(keys1)
    local _keys2 = lowerise(keys2)

    table.sort(_keys1)
    table.sort(_keys2)

    for _, k in ipairs(vim.tbl_keys(_keys1)) do
        if _keys1[k] ~= _keys2[k] then
            return false
        end
    end

    return true
end

local shortcut_starts_with = function(src, search)
    local p = '\\v^(\\<[^\\>]+\\>)'
    if vim.fn.match(src, p) == -1 or vim.fn.match(search, p) == -1 then
        return string.sub(src, 1, string.len(search)) == search
    end

    local _src = src
    local _search = search
    local s1 = vim.fn.matchlist(_src, p)
    local s2 = vim.fn.matchlist(_search, p)
    while #s1 > 0 and #s2 > 0 do
        if not compare_shortcuts(s1[1], s2[1]) then
            return false
        end
        _src = string.gsub(_src, "^" .. string.gsub(s1[1], "%-", "%%-"), "")
        _search = string.gsub(_search, "^" .. string.gsub(s2[1], "%-", "%%-"), "")
        s1 = vim.fn.matchlist(_src, p)
        s2 = vim.fn.matchlist(_search, p)
    end

    if #s2 > 0 then
        return false
    end

    return true
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
    if connection == nil or not string.match(connection, p) then
        return nil
    end
    local proto, bin, host = string.gmatch(connection, p)()
    local cmd = ''
    if proto == 'azul' then
        cmd = bin .. ' -a ' .. uuid() .. ' -m'
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

local is_marionette = function()
    return os.getenv('AZUL_IS_MARIONETTE') == '1'
end

local is_handling_remote = function()
    return os.getenv('AZUL_REMOTE_CONNECTION') ~= nil
end

local safe_close_window = function(win_id)
    local safe, _ = pcall(function() vim.api.nvim_win_close(win_id, true) end)
    return safe
end

local safe_buf_delete = function(buf_id)
    local safe, _ = pcall(function() vim.api.nvim_buf_delete(buf_id, {force = true, unload = false}) end)
    return safe
end

return {
    is_handling_remote = is_handling_remote,
    is_marionette = is_marionette,
    remote_command = remote_command,
    safe_close_window = safe_close_window,
    safe_buf_delete = safe_buf_delete,
    find = find,
    uuid = uuid,
    log = log,
    join = join,
    compare_shortcuts = compare_shortcuts,
    shortcut_starts_with = shortcut_starts_with,
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
