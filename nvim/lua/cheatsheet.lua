local azul = require('azul')
local funcs = require('functions')
local options = require('options')

local win_id = nil
local win_buffer = nil
local mode_win_id = nil
local timer = nil
local timer_set = false
local position_timer = nil

vim.api.nvim_command('highlight AzulCheatsheetArrow guifg=#565f89')

local COL_LEN = 35
local COL_PAD = 2
local WIN_PAD = 4
local ARROW = '➜'

local close_window = function()
    if position_timer ~= nil then
        vim.fn.timer_stop(position_timer)
        position_timer = nil
    end
    if win_id ~= nil then
        vim.api.nvim_win_close(win_id, true)
    end
    win_id = nil
    if win_buffer ~= nil then
        vim.api.nvim_buf_delete(win_buffer, {force = true, unload = false})
    end
    win_buffer = nil
    if timer ~= nil then
        vim.fn.timer_stop(timer)
    end
end

local close_mode_window = function()
    if mode_win_id ~= nil then
        vim.api.nvim_win_close(mode_win_id, true)
    end
    mode_win_id = nil
end

local try_select = function(collection, c)
    local map = funcs.find(function(x) return funcs.get_sensitive_ls(x.ls) == funcs.get_sensitive_ls(c) end, collection)
    if map == nil then
        if azul.get_current_workflow() == 'tmux' then
            azul.feedkeys(c, 'n')
        else
            azul.send_to_current('<C-s>' .. c, true)
        end
        azul.cancel_modifier()
        return false
    else
        azul.run_map(map)
        return true
    end
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

local wait_input = function(mode)
    local collection = get_mappings_for_mode(mode)
    local c = ''
    local before_c = ''
    timer_set = false
    while true do
        -- Prevent Keyboard interrupt error when pressing <C-c>. 
        -- See https://github.com/neovim/neovim/issues/16416
        local cc_map = funcs.find_map('<C-C>', 'n')
        vim.api.nvim_set_keymap('n', '<C-c>', '<Esc>', {})
        local trans = azul.block_input()
        if cc_map ~= nil then
            funcs.restore_map('n', '<C-c>', cc_map)
        else
            vim.api.nvim_del_keymap('n', '<C-c>')
        end
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
                azul.cancel_modifier()
                return
            end
            if new_char == '<cr>' then
                try_select(collection, c)
                return
            end
            if new_char == '<c-s>' and c == '' then
                azul.send_to_current('<c-s>', true)
                azul.cancel_modifier()
                return
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
            return
        end
        if #collection == 1 and funcs.get_sensitive_ls(collection[1].ls) == c then
            azul.run_map(collection[1])
            return
        end
        if #collection == 0 then
            local result = try_select(vim.tbl_filter(function(x) return x.m == mode end, get_mappings_for_mode(mode)), before_c)
            local after = c:gsub("^" .. before_c, "")
            if not result and azul.get_current_workflow() ~= 'tmux' then
                azul.send_to_current(after, true)
            else
                azul.feedkeys(after, mode)
            end
            return
        end
    end
end

local cheatsheet_content = function(mappings, height, full)
    -- A first empty line
    local result = {}
    if full then
        table.insert(result, "")
    end

    local cut_text = function(s, width)
        if string.len(s) <= width then
            return s
        end
        return s:sub(1, width - 3) .. "..."
    end

    local pad = (full and 2) or 1

    local column_width = COL_LEN - COL_PAD
    local widths = {}
    local spaces = string.rep(" ", COL_PAD)
    local max_desc_width = 0
    local max_shortcut_width = 0
    -- Calculate max widths for shortcuts
    for i, map in ipairs(mappings) do
        if max_shortcut_width < string.len(map.ls) then
            max_shortcut_width = string.len(map.ls)
        end

        if math.fmod(i, height) == 0 and i <#mappings then
            table.insert(widths, {
                max_shortcut_width = max_shortcut_width,
                -- three represents the space, arrow space before the shortcut
                pref_max_width = column_width - max_shortcut_width - 3,
            })
            max_shortcut_width = 0
        end
    end
    table.insert(widths, {
        max_shortcut_width = max_shortcut_width,
        pref_max_width = column_width - max_shortcut_width - 3,
    })
    local col_idx = 1
    -- Now, calculate the max widths for descriptions
    for i, map in ipairs(mappings) do
        local txt = cut_text(map.options.desc or 'No description', widths[col_idx].pref_max_width)
        if max_desc_width < string.len(txt) then
            max_desc_width = string.len(txt)
        end

        if math.fmod(i, height) == 0 and i < #mappings then
            widths[col_idx].max_desc_width = max_desc_width
            max_desc_width = 0
            col_idx = col_idx + 1
        end
    end
    widths[col_idx].max_desc_width = max_desc_width

    col_idx = 1
    for i, map in ipairs(mappings) do
        local line_idx = math.fmod(i - 1, height) + pad
        local s = ''
        if type(map) == 'string' then
            s = spaces .. s .. cut_text(map, column_width)
        else
            -- s = s .. map.ls .. " " .. ARROW .. " " .. (map.options.desc or 'No description')
            local pref = cut_text(map.options.desc or 'No description', widths[col_idx].max_desc_width)
            local pref_len = string.len(pref)
            pref = pref .. string.rep(" ", widths[col_idx].max_desc_width - pref_len)
            s = spaces .. pref .. " " .. ARROW .. " " .. string.rep(" ", widths[col_idx].max_shortcut_width - string.len(map.ls)) .. map.ls
            s = s .. string.rep(" ", column_width - string.len(s))
            -- s = s .. (map.options.desc or 'No description') .. " " .. ARROW .. " " .. map.ls
        end

        if result[line_idx] == nil then
            result[line_idx] = string.rep(" ", WIN_PAD)
        end

        result[line_idx] = result[line_idx] .. s
        if math.fmod(i, height) == 0 then
            col_idx = col_idx + 1
        end
    end

    for i, line in ipairs(result) do
        result[i] = line .. string.rep(" ", WIN_PAD)
    end

    if full then
        table.insert(result, "")
        local footer = "<esc> <C-c> " .. ARROW .. " Cancel"
        local spaces = math.ceil((vim.o.columns - math.ceil(footer:len())) / 2)
        local pads = string.rep(" ", spaces)
        table.insert(result, pads .. footer .. pads)
    end

    return result
end

local get_cols_number = function()
    return math.floor((vim.o.columns - (WIN_PAD * 2)) / COL_LEN)
end

local get_top_position = function(height, position)
    local _position = position or options.modes_cheatsheet_position
    local win_top_pos = vim.o.lines - height - 1
    local row = win_top_pos
    local win_height = height
    if _position == 'top' then
        row = 0
    elseif _position == 'auto' then
        local start_line = vim.fn.line('w0')
        local end_line = vim.fn.line('w$')
        local pos = vim.api.nvim_win_get_cursor(0)
        if end_line - pos[1] < win_height then
            row = 0
        elseif pos[1] - start_line < win_height then
            row = win_top_pos
        end
    end

    return row
end

local create_window = function(mappings, full, position)
    local _full
    if full == nil then
        _full = true
    else
        _full = full
    end
    local current_win = vim.api.nvim_get_current_win()
    local cols = get_cols_number()
    local height = math.ceil(#mappings / cols)
    azul.suspend()
    win_buffer = vim.api.nvim_create_buf(false, true)
    local extra_lines = 0
    if _full then
        extra_lines = 4
    end
    local win_height = height + extra_lines
    local win_id = vim.api.nvim_open_win(win_buffer, true, {
        width = vim.o.columns, height = win_height, col = 0, row = get_top_position(win_height, position),
        focusable = false, zindex = 500, border = 'none', relative = 'editor', style = 'minimal',
    })
    vim.filetype.add({
        filename = {
            azul_cheatsheet_window = 'azul_cheatsheet',
        }
    })
    vim.api.nvim_set_option_value('winhighlight', 'Normal:Identifier', {scope = 'local', win = win_id})
    vim.api.nvim_set_option_value('filetype', 'azul_cheatsheet', {buf = win_buffer})
    vim.api.nvim_command("syn match AzulCheatsheetArrow '" .. ARROW .. "'")
    vim.api.nvim_set_current_win(current_win)
    vim.api.nvim_buf_set_lines(win_buffer, 0, height + 3, false, cheatsheet_content(mappings, height, _full))
    azul.resume()
    if position == nil and options.modes_cheatsheet_position == 'auto' then
        position_timer = vim.fn.timer_start(100, function()
            if win_id == nil then
                return
            end

            local config = vim.api.nvim_win_get_config(win_id)
            local row = get_top_position(win_height, 'auto')
            if config.row ~= row then
                config.row = row
                vim.api.nvim_win_set_config(win_id, config)
            end
        end, {['repeat'] = -1})
    end
    return win_id
end

if not options.use_cheatsheet then
    return
end

azul.on_action('show_mode_cheatsheet', function()
    close_window()
    if mode_win_id ~= nil then
        close_mode_window()
        return
    end
    local mode = azul.current_mode()
    local mappings = get_mappings_for_mode(mode)
    if #mappings == 0 or azul.is_modifier_mode(mode) then
        return
    end
    mode_win_id = create_window(mappings, false)
end)

azul.persistent_on('ModeChanged', function(args)
    local new_mode = args[2]
    local mappings = get_mappings_for_mode(new_mode)
    close_window()
    if azul.is_modifier_mode(new_mode) or #mappings == 0 or new_mode == 't' then
        close_mode_window()
        return
    end
    local cols = get_cols_number()
    local x = #mappings
    local more = #mappings >= cols * 2
    while x >= cols * 2 do
        table.remove(mappings, #mappings)
        x = #mappings
    end
    if more then
        local maps = funcs.map_by_action(new_mode, 'show_mode_cheatsheet', azul.get_mode_mappings())
        table.insert(mappings, (#maps > 0 and maps[1]) or "etc.")
    end
    win_id = create_window(mappings, false)
end)

azul.persistent_on('ModifierFinished', function()
    close_window()
end)

azul.persistent_on('ModifierTrigger', function(args)
    local mode = args[1]
    win_id = create_window(get_mappings_for_mode(mode), true, 'bottom')
    if options.blocking_cheatsheet then
        vim.fn.timer_start(0, function()
            wait_input(mode)
        end)
        return
    end
end)
