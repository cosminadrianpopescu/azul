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

local log = function(msg, file)
    if file == nil then
        error("NO LOG TO WRITE TO")
    end
    local f = io.open(file, "a+")
    if f == nil then
        return
    end
    f:write(msg)
    f:write("\n")
    f:close()
end

return {
    get_sensitive_ls = get_sensitive_ls,
    find = find,
    log = log,
}
