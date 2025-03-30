local azul = require('azul')
local funcs = require('functions')
local options = require('options')

local M = {}
local timer_set = false
local timer = nil
local ns_id = nil
local mode_before_modifier = nil

local cancel = function()
    if timer ~= nil then
        vim.fn.timer_stop(timer)
        timer = nil
    end

    if ns_id ~= nil then
        local safe, _ = pcall(function() vim.on_key(nil, ns_id) end)
        if not safe then
            print("There was an error closing the cheatsheet window")
        end
        ns_id = nil
    end
    if mode_before_modifier ~= nil and azul.current_mode() == 'M' then
        azul.enter_mode(mode_before_modifier)
    end
    mode_before_modifier = nil
end

local run_map = function(map)
    azul.run_map(map)
    cancel()
end

local get_mappings_for_mode = function(mode)
    local result = vim.tbl_filter(function(x) return x.m == mode end, azul.get_mode_mappings())
    table.sort(result, function(m1, m2)
        if m1.options.action == 'show_mode_cheatsheet' then
            return false
        end
        if m2.options.action == 'show_mode_cheatsheet' then
            return true
        end
        if type(m1) == 'table' and type(m2) == 'table' then
            return (m1.options.desc or 'No description') < (m2.options.desc or 'No description')
        end
        if type(m2) == 'string' then
            return true
        end
        return false
    end)
    return result
end

local try_select = function(collection, c)
    local map = funcs.find(function(x) return funcs.get_sensitive_ls(x.ls) == funcs.get_sensitive_ls(c) end, collection)
    if map == nil then
        if azul.get_current_workflow() == 'tmux' then
            azul.feedkeys(c, 'n')
        else
            azul.send_to_current('<C-s>' .. c, true)
        end
        cancel()
        return false
    else
        run_map(map)
        return true
    end
end

local get_mappings = function(mode)
    local all_mappings = azul.get_mode_mappings()
    return (mode == nil and all_mappings) or vim.tbl_filter(function(x) return x.m == mode end, all_mappings)
end

M.unmap_all = function(mode)
    local collection = get_mappings(mode)
    for _, m in ipairs(collection) do
        local cmd = m.real_mode .. 'unmap ' .. m.ls
        local result = pcall(function() vim.api.nvim_command(cmd) end)
        if not result and mode ~= nil then
            print(cmd .. " failed")
        end
    end
end

M.remap_all = function(mode)
    local collection = get_mappings(mode)
    -- for _, m in ipairs(collection) do
    --     vim.api.nvim_set_keymap(m.real_mode, m.ls, m.rs, m.options)
    -- end
    for _, m in ipairs(collection) do
        vim.api.nvim_set_keymap(m.real_mode, m.ls, '', {
            callback = function()
                -- M.unmap_all(mode, modifier)
                run_map(m)
            end,
            desc = m.desc,
        })
    end
end

local key_handler = function(mode)
    local collection = get_mappings_for_mode(mode)
    local c = ''
    local before_c = ''
    timer_set = false

    local process_input = function(key)
        local trans = vim.fn.keytrans(key)
        if not timer_set then
            timer = vim.fn.timer_start(options.modifer_timeout, function()
                timer = nil
                azul.feedkeys("<esc>", mode)
            end)
            timer_set = true
        end
        if timer ~= nil then
            local new_char = funcs.get_sensitive_ls(trans)
            if new_char == "<c-c>" or new_char == '<Esc>' then
                cancel()
                funcs.log("CANCEL")
                vim.fn.timer_start(1, function()
                    vim.api.nvim_command('startinsert')
                end)
                return ''
            end
            if new_char == '<cr>' then
                try_select(collection, c)
                return ''
            end
            if new_char == funcs.get_sensitive_ls(options.modifier) and c == '' then
                -- cancel()
                -- vim.fn.timer_start(1, function()
                --     azul.send_to_current('<C-s>', true)
                -- end)
                vim.fn.timer_start(1, function()
                    azul.send_to_current(options.modifier, true)
                    vim.fn.timer_start(1, function()
                        cancel()
                    end)
                end)
                return ''
            end
            before_c = c
            c = c .. new_char
            collection = vim.tbl_filter(function(x)
                local s = funcs.get_sensitive_ls(x.ls)
                return string.sub(s, 1, string.len(c)) == c
            end, collection)

            -- collection = vim.tbl_filter(function(x) return funcs.get_sensitive_ls(x.ls):match("^" .. c) end, collection)
        end
        if timer == nil then
            try_select(collection, c)
            return ''
        end
        if #collection == 1 and funcs.get_sensitive_ls(collection[1].ls) == c then
            run_map(collection[1])
            return ''
        end
        if #collection == 0 then
            local result = try_select(vim.tbl_filter(function(x) return x.m == mode end, get_mappings_for_mode(mode)), before_c)
            local after = c:gsub("^" .. before_c, "")
            if not result and azul.get_current_workflow() ~= 'tmux' then
                azul.send_to_current(after, true)
            else
                azul.feedkeys(after, mode)
            end
            return ''
        end

        return ''
    end

    ns_id = vim.on_key(function(_, key)
        return process_input(key)
    end)
end

azul.persistent_on('ModeChanged', function(args)
    local old_mode = args[1]
    local new_mode = args[2]

    if new_mode == 'M' then
        mode_before_modifier = old_mode
        vim.fn.timer_start(0, function()
            key_handler(new_mode)
        end)
        return
    end

    cancel()

    if not azul.is_modifier_mode(old_mode) then
        M.unmap_all(old_mode)
    end

    if not azul.is_modifier_mode(new_mode) then
        M.remap_all(new_mode)
    end
end)

return M
