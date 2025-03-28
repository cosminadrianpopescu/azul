local uuid = require('uuid').uuid;
local base_path = '/tmp/azul-' .. uuid
local job = require('plenary.job')
local funcs = require('functions')
local options = require('options')
local config = require('config')
local test_running = nil
local azul = require('azul')

vim.g.azul_errors_log = base_path .. "/runtime-errors"
local TIMEOUT_BETWEEN_KEYS = 150

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
    return require('split').split(s, ' ')
    -- local tag = ''
    -- local result = {}
    -- for i = 1, #s do
    --     local c = s:sub(i, i)
    --     if c == '<' then
    --         tag = '<'
    --     elseif c == '>' then
    --         tag = tag .. '>'
    --         table.insert(result, tag)
    --         tag = ''
    --     else
    --         if tag == '' then
    --             table.insert(result, c)
    --         else
    --             tag = tag .. c
    --         end
    --     end
    -- end

    -- return result
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
L.simulate_keys = function(keys, idx, after)
    if idx > #keys then
        if after ~= nil then
            vim.fn.timer_start(1, function()
                after()
            end)
        end
        return
    end
    if keys[idx] ~= '' then
        azul.feedkeys(keys[idx], 't')
    end
    vim.fn.timer_start(TIMEOUT_BETWEEN_KEYS - ((options.workflow == 'emacs' and 120) or 0), function()
        L.simulate_keys(keys, idx + 1, after)
    end)
end

local check_trigger_after = function(events, ran)
    if #vim.tbl_keys(events) ~= #vim.tbl_keys(ran) and options.workflow ~= 'emacs' then
        return false
    end

    for ev, count in pairs(events) do
        if (ran[ev] == nil or count > ran[ev]) and (ev ~= 'ModeChanged' or options.workflow ~= 'emacs') then
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

local default_shortcut_mode = function(action)
    if options.workflow == 'azul' or options.workflow == 'emacs' then
        return 't'
    end

    if options.workflow == 'tmux' then
        return 'n'
    end

    if vim.tbl_contains({'create_float', 'toggle_floats'}, action) then
        return 'p'
    end

    if vim.tbl_contains({'create_tab', 'tab_select'}, action) then
        return 'T'
    end

    return 't'
end

L.action_shortcut = function(action, mode, arg, with_modifier)
    if action == 'enter_mode' and options.workflow == 'emacs' then
        return ''
    end

    if options.workflow == 'emacs' then
        mode = 't'
    end

    local default_mode = default_shortcut_mode(action)
    local map = funcs.find(function(m) return ((arg ~= nil and m.arg == arg) or m.arg == nil) and m.action == action  and m.mode == (mode or default_mode) end, config.ini_shortcuts)
    if map == nil then
        quit("Could not find map for " .. action .. " in mode " .. vim.inspect(mode))
    end

    if with_modifier == false then
        return map.shortcut
    end

    if (options.workflow == 'tmux' or options.workflow == 'azul') and (mode == default_mode or mode == nil) then
        return options.modifier .. ' ' .. map.shortcut
    end

    if options.workflow == 'zellij' and mode == nil and default_mode ~= 't' then
        return L.action_shortcut('enter_mode', 't', default_mode) .. ' ' .. map.shortcut
    end

    return map.shortcut
end

local _do_action_with_modifier = function(action, arg, events, callback)
    local shortcut_mode = 't'
    if options.workflow == 'tmux' then
        shortcut_mode = 'n'
    elseif options.workflow == 'zellij' then
        shortcut_mode = 'p'
    end
    local shortcut = L.action_shortcut(action, shortcut_mode, arg, false)
    wait_events(events, callback)
    if options.workflow == 'azul' or options.workflow == 'tmux' then
        L.simulate_keys({options.modifier}, 1, function()
            L.simulate_keys(extract_chars(shortcut), 1)
        end)
    end
end

local simulate_map = function(ls, mode, callback)
    local map = funcs.find(function(m) return m.ls == ls and m.m == mode end, azul.get_mode_mappings())
    if map == nil then
        quit("Could not find mapping for " .. ls .. " in mode " .. mode)
    end
    if map.options.callback ~= nil then
        map.options.callback()
    elseif map.rs ~= nil then
        azul.feedkeys(map.rs, map.real_mode)
    end
    callback()
end

L.do_simulate_maps = function(lss, mode, idx)
    if idx > #lss then
        return
    end
    simulate_map(lss[idx], mode, function()
        L.do_simulate_maps(lss, mode, idx + 1)
    end)
end

local simulate_maps = function(lss, mode, events, callback)
    wait_events(events, callback)
    L.do_simulate_maps(lss, mode, 1)
end

local do_action = function(action, callback)
    _do_action_with_modifier(action, nil, {PaneChanged = 1}, callback)
end

local enter_mode = function(mode, callback)
    _do_action_with_modifier('enter_mode', mode, {ModeChanged = (options.workflow == 'tmux' and 2) or 1}, callback)
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
        local do_exec = false
        wait_events(events, function()
            do_exec = true
        end)
        L.simulate_keys(extract_chars(what), 1, function()
            if (events == nil and after ~= nil) or (after ~= nil and (do_exec or #events == 0)) then
                after()
            end
        end)
    end,
    wait_events = wait_events,
    action_shortcut = L.action_shortcut,
    single_shot = single_shot,
    set_test_running = function(which)
        test_running = which
    end,
    do_action = do_action,
    enter_mode = enter_mode,
    simulate_maps = simulate_maps,
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
