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

return {
    get_sensitive_ls = get_sensitive_ls,
    find = find,
    log = log,
    safe_get_tab_var = safe_get_tab_var,
    safe_del_tab_var = safe_del_tab_var,
    find_map = find_map,
    restore_map = restore_map,
}
