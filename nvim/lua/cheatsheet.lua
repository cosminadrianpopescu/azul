local core = require('core')
local funcs = require('functions')
local options = require('options')
local EV = require('events')
local ERRORS = require('error_handling')

local win_id = nil
local win_buffer = nil
local mode_win_id = nil
local position_timer = nil
local commands_palette = false

vim.api.nvim_command('highlight VesperCheatsheetArrow guifg=#565f89')

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
        if vim.api.nvim_win_is_valid(win_id) and not funcs.safe_close_window(win_id) then
            print("There was an error closing the window with id " .. win_id .. ". You'll probably need to close it manually.")
        end
    end
    win_id = nil
    if win_buffer ~= nil then
        if vim.api.nvim_buf_is_valid(win_buffer) and not funcs.safe_buf_delete(win_buffer) then
            print("There was an error removing the buffer " .. vim.inspect(win_buffer) .. ". You'll probably need to remove it manually.")
        end
    end
    win_buffer = nil
end

local close_mode_window = function()
    if mode_win_id ~= nil then
        funcs.safe_close_window(mode_win_id)
    end
    mode_win_id = nil
end

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
    core.suspend()
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
            vesper_cheatsheet_window = 'vesper_cheatsheet',
        }
    })
    vim.api.nvim_set_option_value('winhighlight', 'Normal:Identifier', {scope = 'local', win = win_id})
    vim.api.nvim_set_option_value('filetype', 'vesper_cheatsheet', {buf = win_buffer})
    vim.api.nvim_command("syn match VesperCheatsheetArrow '" .. ARROW .. "'")
    vim.api.nvim_set_current_win(current_win)
    vim.api.nvim_buf_set_lines(win_buffer, 0, height + 3, false, cheatsheet_content(mappings, height, _full))
    core.resume()
    if position == nil and options.modes_cheatsheet_position == 'auto' then
        position_timer = ERRORS.defer(100, function()
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

EV.on_action('show_mode_cheatsheet', function()
    if not options.use_cheatsheet then
        return
    end
    close_window()
    if mode_win_id ~= nil then
        close_mode_window()
        return
    end
    local mode = core.current_mode()
    local mappings = get_mappings_for_mode(mode)
    if #mappings == 0 or core.is_modifier_mode(mode) then
        return
    end
    mode_win_id = create_window(mappings, false)
end)

EV.persistent_on('CommandPaletteOpen', function()
    close_window()
    commands_palette = true
end)

EV.persistent_on('CommandPaletteClosed', function()
    commands_palette = false
end)

EV.persistent_on('ModeChanged', function(args)
    if not options.use_cheatsheet or commands_palette then
        return
    end
    local new_mode = args[2]
    if new_mode == 'M' then
        win_id = create_window(get_mappings_for_mode(new_mode), true, 'bottom')
        return
    end
    local mappings = get_mappings_for_mode(new_mode)
    close_window()
    if core.is_modifier_mode(new_mode) or #mappings == 0 or new_mode == 't' or new_mode == 'P' then
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
        local maps = funcs.map_by_action(new_mode, 'show_mode_cheatsheet', core.get_mode_mappings())
        table.insert(mappings, (#maps > 0 and maps[1]) or "etc.")
    end
    win_id = create_window(mappings, false)
end)
