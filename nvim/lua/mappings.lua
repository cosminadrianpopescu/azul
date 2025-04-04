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
        funcs.log("RESETTING")
        collection = get_mappings_for_mode(mode)
        funcs.log("FOUND COLLECTION OF " .. vim.inspect(#collection) .. " IN " .. vim.inspect(mode))
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
        funcs.log("CHANGE COLLECTION FOR " .. vim.inspect(mode) .. " => " .. vim.inspect(#collection))
    end)

    local run_map = function(map)
        azul.run_map(map)
        reset()
    end

    local try_select = function(collection, c)
        funcs.log("TRY SELECTING " .. vim.inspect(c))
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
        funcs.log("PROCESSING MODIFIER")
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
            funcs.log("IGNORING " .. vim.inspect(trans) .. " WITH " .. vim.inspect(ignore_keys) .. " AND " .. vim.inspect(ignored_keys_count))
            ignored_keys_count = ignored_keys_count + 1
            if ignored_keys_count == ignore_keys then
                ignore_keys = 0
                ignored_keys_count = 0
                funcs.log("RUNNING AFTER")
                run_after_ignore()
            end
            return nil
        end
        funcs.log("PROCESSING " .. vim.inspect(trans) .. " IN " .. vim.inspect(azul.current_mode()))
        if funcs.compare_shortcuts(trans, options.modifier)
            and azul.current_mode() == 't' and buffer == '' and not timer_set and timer == nil
            and (options.workflow == 'tmux' or options.workflow == 'azul')
        then
            return process_modifier()
        end
        reset_timer()
        timer = vim.fn.timer_start(options.modifer_timeout, function()
            funcs.log("TRY SELECT 1")
            try_select(collection, c)
            reset()
        end)
        timer_set = true
        funcs.log("TIMER SET " .. vim.inspect(timer))
        if azul.current_mode() == 'M' then
            if funcs.compare_shortcuts(trans, "<C-c>") or funcs.compare_shortcuts(trans, "<esc>") then
                reset()
                vim.fn.timer_start(1, function()
                    vim.api.nvim_command('startinsert')
                end)
                funcs.log("RETURNING empty 6")
                return ''
            end
            if funcs.compare_shortcuts(trans, '<cr>') then
                funcs.log("TRY SELECT 2")
                try_select(collection, c)
                funcs.log("RETURNING empty 5")
                return ''
            end
            if funcs.compare_shortcuts(trans, options.modifier) and c == '' then
                azul.send_to_current(options.modifier, true)
                vim.fn.timer_start(1, function()
                    reset()
                    vim.api.nvim_command('startinsert')
                end)
                funcs.log("RETURNING empty 4")
                return ''
            end
            buffer = c
        end
        c = c .. trans
        funcs.log("SEARCHING FOR " .. vim.inspect(c) .. " AS " .. vim.inspect(c) .. " IN " .. vim.inspect(#collection))
        collection = vim.tbl_filter(function(x) return funcs.shortcut_starts_with(x.ls, c) end, collection)
        funcs.log("FOUND " .. vim.inspect(#collection))
        if timer == nil then
            funcs.log("TRY SELECT 3")
            try_select(collection, c)
            funcs.log("RETURNING empty 3")
            return ''
        end
        if #collection == 1 and funcs.compare_shortcuts(collection[1].ls, c) then
            run_map(collection[1])
            funcs.log("RETURNING empty 2 " .. vim.inspect(vim.fn.mode()))
            return ''
        end
        if #collection == 0 then
            if azul.current_mode() == 'M' then
                funcs.log("TRY SELECT 4")
                local mode_before = mode
                local result = try_select(vim.tbl_filter(function(x) return x.m == mode end, get_mappings_for_mode(mode)), buffer)
                local after = c:gsub("^" .. buffer, "")
                if not result then
                    funcs.log("FEED " .. vim.inspect(after))
                    azul.feedkeys(after, mode)
                elseif mode_before ~= azul.current_mode() then
                    collection = get_mappings_for_mode(azul.current_mode())
                    me(trans, me)
                end
                funcs.log("RETURNING empty 1")
                reset()
                return ''
            end
            funcs.log("SEND " .. vim.inspect(c) .. " IN MODE " .. vim.fn.mode())
            -- azul.feedkeys(c, vim.fn.mode())
            reset()
            funcs.log("RETURNING NIL 3")
            return nil
        end

        if azul.current_mode() == 'M' then
            funcs.log("RETURNING NIL 2")
            return ''
        end

        funcs.log("RETURNING NIL 1")
        reset()
        return nil
    end

    ns_id = vim.on_key(function(_, key)
        if key == "" then
            reset()
            return nil
        end
        funcs.log("RECEIVED " .. vim.inspect(_) .. " AND " .. vim.inspect(key))
        return process_input(key, process_input)
    end)
    funcs.log("ADDED  " .. vim.inspect(ns_id))
end

azul.persistent_on('AzulStarted', function()
    generic_key_handler()
end)
