
local tab_vars = {}

local M = {}

local get_real_id = function(id)
    if id ~= 0 then
        return 'tab-' .. id
    end
    return 'tab-' .. vim.api.nvim_list_tabpages()[vim.fn.tabpagenr()]
end

M.set_var = function(id, key, value)
    local real_id = get_real_id(id)
    if tab_vars[real_id] == nil then
        tab_vars[real_id] = {}
    end
    local map = tab_vars[real_id]
    map[key] = value
end

M.get_var = function(id, key)
    local real_id = get_real_id(id)
    if tab_vars[real_id] == nil then
        return nil
    end

    return tab_vars[real_id][key]
end

M.del_var = function(id, key)
    local real_id = get_real_id(id)
    if tab_vars[real_id] == nil then
        return
    end
    tab_vars[real_id][key] = nil
end

M.debug = function()
    return tab_vars
end

return M
