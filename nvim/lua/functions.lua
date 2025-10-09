local options = require('options')

math.randomseed()

local split = function(s, delimiter)
    local result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return vim.tbl_filter(function(x) return x ~= '' end, result);
end

local run_process = function(cmd)
    local x = io.popen(cmd)
    local result = x:read('*all')
    x:close()
    return vim.fn.substitute(result, '\\v[\\n]+$', '', 'g')
end

local run_process_list = function(cmd)
    return split(run_process(cmd), '\n')
end

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
    local p = '\\v^(\\<[^>]+\\>)'
    if vim.fn.match(src, p) == -1 or vim.fn.match(search, p) == -1 then
        return string.sub(src, 1, string.len(search)) == search
    end

    local _src = string.lower(src)
    local _search = string.lower(search)
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
        file = "/tmp/azul-log-" .. os.getenv('AZUL_SESSION')
    end
    local f = io.open(file, "a+")
    if f == nil then
        return
    end
    f:write(msg)
    f:write("\n")
    f:close()
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

-- local safe_close_window = function(win_id)
--     if not vim.api.nvim_win_is_valid(win_id) then
--         return false
--     end
--     vim.api.nvim_win_close(win_id, true)
-- end

local safe_buf_delete = function(buf_id)
    local safe, _ = pcall(function() vim.api.nvim_buf_delete(buf_id, {force = true, unload = false}) end)
    return safe
end

local session_child_file = function(for_parent)
    local name = os.getenv((for_parent and 'AZUL_PARENT_SESSION') or 'AZUL_SESSION')
    if name == nil then
        name = ''
    end
    return os.getenv('AZUL_RUN_DIR') .. '/' .. name .. '-child'
end

local safe_put_text_to_buffer = function(buf, row, col, txt, after, me)
    local safe, _ = pcall(function()
        vim.api.nvim_buf_set_text(buf, row, col, row, col, {txt})
    end)

    if not safe then
        vim.fn.timer_start(1, function()
            me(buf, row, col, txt, after, me)
        end)
    else
        after()
    end
end

local deserialize = function(var)
    return loadstring("return " .. string.gsub(var, "\\n", "\n"))()
end

local is_autosave = function()
    return os.getenv('AZUL_NO_AUTOSAVE') ~= '1' and (options.autosave == 'always' or options.autosave == 'often')
end

local is_float = function(t)
    return t and t.win_config and t.win_config['zindex'] ~= nil
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

local term_by_panel_id = function(id, terminals)
    return find(function(t) return t.panel_id .. '' == id .. '' end, terminals)
end

local _buf = function(t)
    return t.editing_buf or t.buf
end

local get_visible_floatings = function(terminals)
    return vim.tbl_filter(function(t) return is_float(t) and t.win_id ~= nil end, terminals)
end

local get_all_floats = function(group, terminals)
    return vim.tbl_filter(function(t) return is_float(t) and ((group ~= nil and t.group == group) or group == nil) end, terminals)
end

local are_floats_hidden = function(group, terminals)
    local floatings = get_all_floats(group, terminals)
    if #floatings == 0 then
        return true
    end
    return #vim.tbl_filter(function(t) return t.win_id == nil and t.group == (group or 'default') end, floatings) > 0
end

local get_float_title = function(t)
    return t.overriden_title or options.float_pane_title
end

--- Returns the reomote state of a pane (nil means the pane is not a remote pane). If the pane is remote, it will
--- return connected or disconnected
--- @param t terminals The pane to be analyzed
local remote_state = function(t)
    if t == nil or t.remote_command == nil then
        return nil
    end

    return (t.term_id == nil and 'disconnected') or 'connected'
end

return {
    is_handling_remote = is_handling_remote,
    is_marionette = is_marionette,
    remote_command = remote_command,
    session_child_file = session_child_file,
    safe_close_window = safe_close_window,
    safe_buf_delete = safe_buf_delete,
    safe_put_text_to_buffer = function(buf, row, col, txt, after)
        safe_put_text_to_buffer(buf, row, col, txt, after, safe_put_text_to_buffer)
    end,
    find = find,
    uuid = uuid,
    log = log,
    join = join,
    compare_shortcuts = compare_shortcuts,
    shortcut_starts_with = shortcut_starts_with,
    safe_get_buf_var = safe_get_buf_var,
    safe_del_buf_var = safe_del_buf_var,
    find_map = find_map,
    map_by_action = map_by_action,
    current_float_group = current_float_group,
    regexp_group = regexp_group,
    run_process = run_process,
    run_process_list = run_process_list,
    deserialize = deserialize,
    is_autosave = is_autosave,
    is_float = is_float,
    reverse = reverse,
    term_by_panel_id = term_by_panel_id,
    get_real_buffer = _buf,
    get_visible_floatings = get_visible_floatings,
    are_floats_hidden = are_floats_hidden,
    get_float_title = get_float_title,
    get_all_floats = get_all_floats,
    remote_state = remote_state,
}
