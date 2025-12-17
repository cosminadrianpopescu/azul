local core = require('core')
local EV = require('events')
local funcs = require('functions')
local options = require('options')
local FILES = require('files')
local INS = require('insert')

local is_editing = false

local ns_id = vim.api.nvim_create_namespace('VIM_ON_KEY')
local M = {}

local key_parsers = {}
local id = 0

local get_mappings_for_mode = function(mode)
    local result = vim.tbl_filter(function(x) return x.m == mode end, core.get_mode_mappings())
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

local generic_key_handler = function()
    local mode = core.current_mode()
    local collection = {}
    local set_collection = function()
        collection = get_mappings_for_mode(mode)
        if is_editing then
            collection = {}
        end
    end
    set_collection()
    local c = ''
    local buffer = ''
    local timer = nil
    local timer_set = false
    local mode_before_modifier = nil

    local reset_timer = function()
        timer_set = false
        if timer ~= nil then
            vim.fn.timer_stop(timer)
            timer = nil
        end
    end

    local reset = function()
        set_collection()
        buffer = ''
        c = ''
        timer_set = false
        reset_timer()

        if mode_before_modifier ~= nil and core.current_mode() == 'M' then
            core.enter_mode(mode_before_modifier)
        end
        mode_before_modifier = nil
    end

    EV.persistent_on('ModeChanged', function(args)
        local old_mode = args[1]
        vim.fn.timer_start(1, function()
            mode = core.current_mode()
            if mode == 'M' then
                mode_before_modifier = old_mode
            end
            collection = get_mappings_for_mode(mode)
        end)
    end)

    EV.persistent_on('UserInputPrompt', function()
        is_editing = true
    end)

    EV.persistent_on({'UserInput', 'Error'}, function()
        is_editing = false
    end)

    local run_map = function(map)
        require('core').run_map(map)
        reset()
    end

    local try_select = function(collection, c)
        local map = funcs.find(function(x) return funcs.compare_shortcuts(x.ls, c) end, collection)
        if map == nil then
            local t = core.get_current_terminal()
            if t.term_id == nil then
                core.feedkeys(c, 'n')
            else
                core.send_to_current(c, true)
            end
            -- reset()
            return false
        else
            run_map(map)
            return true
        end
    end

    local process_modifier = function()
        if INS.is_editing() then
            return nil
        end
        if core.current_mode() == 'P' then
            core.send_to_current(options.modifier, true)
            return ''
        end
        if options.workflow == 'tmux' and core.current_mode() ~= 'n' and core.current_mode() ~= 'a' then
            vim.api.nvim_command('stopinsert')
            vim.fn.timer_start(1, function()
                core.enter_mode('M')
            end)
        else
            core.enter_mode('M')
        end

        return ''
    end

    local process_input = function(key, me)
        local trans = string.gsub(vim.fn.keytrans(key), "Bslash", "\\")
        if trans == '' then
            reset()
            return nil
        end
        local block = false
        for _, parser in pairs(key_parsers) do
            if parser(trans) == true then
                block = true
            end
        end

        if block then
            return ''
        end

        if core.current_mode() == 'n' or core.current_mode() == 'a' then
            if trans == ':' and options.strict_scroll then
                return ''
            end
        end
        if funcs.compare_shortcuts(trans, options.modifier)
            and core.current_mode() == 't' and buffer == '' and not timer_set and timer == nil
            and (options.workflow == 'tmux' or options.workflow == 'vesper')
        then
            return process_modifier()
        end
        -- Do I really want to ignore ':' in case of non vesper or modifier mode?!
        -- if trans == ':' and core.current_mode() ~= 'a' and core.current_mode() ~= 'M' and not INS.is_editing() then
        --     return ''
        -- end
        reset_timer()
        timer = vim.fn.timer_start(options.modifer_timeout, function()
            try_select(collection, c)
            reset()
        end)
        timer_set = true
        if core.current_mode() == 'M' then
            if funcs.compare_shortcuts(trans, "<C-c>") or funcs.compare_shortcuts(trans, "<esc>") then
                reset()
                vim.fn.timer_start(1, function()
                    vim.api.nvim_command('startinsert')
                end)
                return ''
            end
            if funcs.compare_shortcuts(trans, '<cr>') then
                try_select(collection, c)
                return ''
            end
            if funcs.compare_shortcuts(trans, options.modifier) and c == '' then
                core.send_to_current(options.modifier, true)
                vim.fn.timer_start(1, function()
                    reset()
                    vim.api.nvim_command('startinsert')
                end)
                return ''
            end
            buffer = c
        end
        c = c .. trans
        collection = vim.tbl_filter(function(x) return funcs.shortcut_starts_with(x.ls, c) end, collection)
        if timer == nil then
            try_select(collection, c)
            return ''
        end
        if #collection == 1 and funcs.compare_shortcuts(collection[1].ls, c) then
            run_map(collection[1])
            return ''
        end
        if #collection == 0 then
            if core.current_mode() == 'M' then
                local mode_before = mode
                local result = try_select(vim.tbl_filter(function(x) return x.m == mode end, get_mappings_for_mode(mode)), buffer)
                local after = c:gsub("^" .. buffer, "")
                if not result then
                    core.feedkeys(after, mode)
                elseif mode_before ~= core.current_mode() then
                    collection = get_mappings_for_mode(core.current_mode())
                    me(trans, me)
                end
                reset()
                return ''
            end
            -- core.feedkeys(c, vim.fn.mode())
            reset()
            return nil
        end

        if core.current_mode() == 'M' then
            return ''
        end

        -- reset()
        return ''
    end

    vim.on_key(function(_, key)
        if key == "" then
            reset()
            return nil
        end
        local safe, result = pcall(function() return process_input(key, process_input) end)
        if not safe then
            print(result)
            reset()
            return ''
        end
        if result == 'skip' then
            return nil
        end
        return result
    end, ns_id)
end

local has_child_sessions_in_passthrough = function()
    local f = funcs.session_child_file()
    if not FILES.exists(f) then
        return false
    end

    local content = FILES.read_file(f)
    return content:gsub('[\n\r\t]', '') == 'true'
end

core.set_key_map('P', options.passthrough_escape, '', {
    callback = function()
        if has_child_sessions_in_passthrough() then
            core.send_to_current(options.passthrough_escape, true)
            return
        end
        core.enter_mode('t')
    end
})

EV.persistent_on('VesperStarted', function()
    generic_key_handler()
end)

M.add_key_parser = function(callback)
    key_parsers['key-parser-' .. id] = callback
    id = id + 1
    return id - 1
end

M.remove_key_parser = function(id)
    key_parsers['key-parser-' .. id] = nil
end

return M
