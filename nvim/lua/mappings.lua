local azul = require('azul')
local funcs = require('functions')
local options = require('options')

local ns_id = nil

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

local generic_key_handler = function()
    local mode = azul.current_mode()
    local collection = get_mappings_for_mode(mode)
    local c = ''
    local buffer = ''
    local timer = nil
    local timer_set = false
    local mode_before_modifier = nil
    local ignore_keys = 0
    local run_after_ignore = nil
    local ignored_keys_count = 0

    local reset_timer = function()
        timer_set = false
        if timer ~= nil then
            vim.fn.timer_stop(timer)
            timer = nil
        end
    end

    local reset = function()
        collection = get_mappings_for_mode(mode)
        buffer = ''
        c = ''
        timer_set = false
        reset_timer()

        if mode_before_modifier ~= nil and azul.current_mode() == 'M' then
            azul.enter_mode(mode_before_modifier)
        end
        mode_before_modifier = nil
    end

    local run_after = function(count, callback)
        ignored_keys_count = 0
        ignore_keys = count
        run_after_ignore = callback
    end

    azul.persistent_on('ModeChanged', function(args)
        local old_mode = args[1]
        mode = args[2]
        if mode == 'M' then
            mode_before_modifier = old_mode
        end
        collection = get_mappings_for_mode(mode)
    end)

    local run_map = function(map)
        azul.run_map(map)
        reset()
    end

    local try_select = function(collection, c)
        local map = funcs.find(function(x) return funcs.compare_shortcuts(x.ls, c) end, collection)
        if map == nil then
            azul.send_to_current(c, true)
            -- reset()
            return false
        else
            run_map(map)
            return true
        end
    end

    local process_modifier = function()
        if azul.current_mode() == 'P' then
            azul.send_to_current(options.modifier, true)
            return ''
        end
        if options.workflow == 'tmux' and azul.current_mode() ~= 'n' then
            azul.enter_mode('n')
            azul.feedkeys('<C-\\><C-n>', 't')
            run_after(2, function()
                vim.fn.timer_start(1, function()
                    azul.enter_mode('M')
                end)
            end)
        else
            azul.enter_mode('M')
        end

        return ''
    end

    local process_input = function(key, me)
        local trans = vim.fn.keytrans(key)
        if trans == '' then
            reset()
            return nil
        end
        if ignore_keys > 0 and ignored_keys_count < ignore_keys then
            ignored_keys_count = ignored_keys_count + 1
            if ignored_keys_count == ignore_keys then
                ignore_keys = 0
                ignored_keys_count = 0
                run_after_ignore()
            end
            return nil
        end
        if funcs.compare_shortcuts(trans, options.modifier)
            and azul.current_mode() == 't' and buffer == '' and not timer_set and timer == nil
            and (options.workflow == 'tmux' or options.workflow == 'azul')
        then
            return process_modifier()
        end
        reset_timer()
        timer = vim.fn.timer_start(options.modifer_timeout, function()
            try_select(collection, c)
            reset()
        end)
        timer_set = true
        if azul.current_mode() == 'M' then
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
                azul.send_to_current(options.modifier, true)
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
            if azul.current_mode() == 'M' then
                local mode_before = mode
                local result = try_select(vim.tbl_filter(function(x) return x.m == mode end, get_mappings_for_mode(mode)), buffer)
                local after = c:gsub("^" .. buffer, "")
                if not result then
                    azul.feedkeys(after, mode)
                elseif mode_before ~= azul.current_mode() then
                    collection = get_mappings_for_mode(azul.current_mode())
                    me(trans, me)
                end
                reset()
                return ''
            end
            -- azul.feedkeys(c, vim.fn.mode())
            reset()
            return nil
        end

        if azul.current_mode() == 'M' then
            return ''
        end

        -- reset()
        return ''
    end

    ns_id = vim.on_key(function(_, key)
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
        return result
    end)
end

azul.persistent_on('AzulStarted', function()
    generic_key_handler()
end)
