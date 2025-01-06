local azul = require('azul')
local funcs = require('functions')
local M = {}
local cfg = require('config')

local win_id = nil
local mappings = {
    modifier = nil,
    esc = nil,
    cc = nil,
}
local timer = nil
local timer_set = false

vim.api.nvim_command('highlight AzulCheatsheetArrow guifg=#565f89')

local COL_LEN = 35
local COL_PAD = 2
local WIN_PAD = 4
local ARROW = '➜'

local close_window = function(win_id)
    vim.api.nvim_win_close(win_id, true)
    if timer ~= nil then
        vim.fn.timer_stop(timer)
    end
end

local select = function(m, mode, win_id)
    local err
    if m.options.callback ~= nil then
        _, err = pcall(function() m.options.callback() end)
    elseif m.rs ~= nil then
        _, err = pcall(function() azul.feedkeys(m.rs, mode) end)
    end
    close_window(win_id)
    if err then
        error(err)
    end
end

local try_select = function(collection, c, mode, win_id)
    local map = funcs.find(function(x) return funcs.get_sensitive_ls(x.ls) == funcs.get_sensitive_ls(c) end, collection)
    if map == nil then
        if azul.get_current_workflow() == 'tmux' then
            azul.feedkeys(c, 'n')
        else
            azul.send_to_current('<C-s>' .. c, true)
        end
        close_window(win_id)
        return false
    else
        select(map, mode, win_id)
        return true
    end
end

local get_mappings_for_mode = function(mode)
    return vim.tbl_filter(function(x) return x.m == mode end, azul.get_mode_mappings())
end

local find_map = function(which, mode)
    return funcs.find(function(m) return m.lhs == which end, vim.api.nvim_get_keymap(mode))
end

local restore_map = function(mode, which, map)
    vim.api.nvim_set_keymap(mode, which, map.rhs or '', {
        nowait = map.nowait, silent = map.silent, expr = map.expr,
        unique = map.unique, callback = map.callback or nil,
        noremap = map.noremap, desc = map.desc,
    })
end

local wait_input = function(mode, win_id)
    local collection = get_mappings_for_mode(mode)
    local c = ''
    local before_c = ''
    timer_set = false
    while true do
        -- Prevent Keyboard interrupt error when pressing <C-c>. 
        -- See https://github.com/neovim/neovim/issues/16416
        local cc_map = find_map('<C-C>', 'n')
        vim.api.nvim_set_keymap('n', '<C-c>', '<Esc>', {})
        local trans = azul.block_input()
        if cc_map ~= nil then
            restore_map('n', '<C-c>', cc_map)
        else
            vim.api.nvim_del_keymap('n', '<C-c>')
        end
        if not timer_set then
            timer = vim.fn.timer_start(cfg.default_config.options.modifer_timeout, function()
                timer = nil
                azul.feedkeys("<esc>", mode)
            end)
            timer_set = true
        end
        if timer ~= nil then
            local new_char = funcs.get_sensitive_ls(trans)
            if new_char == "<c-c>" or new_char == '<Esc>' then
                close_window(win_id)
                return
            end
            if new_char == '<cr>' then
                try_select(collection, c, mode, win_id)
                return
            end
            if new_char == '<c-s>' and c == '' then
                azul.send_to_current('<c-s>', true)
                close_window(win_id)
                return
            end
            before_c = c
            c = c .. new_char
            collection = vim.tbl_filter(function(x) return funcs.get_sensitive_ls(x.ls):match("^" .. c) end, collection)
        end
        if timer == nil then
            try_select(collection, c, mode, win_id)
            return
        end
        if #collection == 1 and funcs.get_sensitive_ls(collection[1].ls) == c then
            select(collection[1], mode, win_id)
            return
        end
        if #collection == 0 then
            local result = try_select(vim.tbl_filter(function(x) return x.m == mode end, get_mappings_for_mode(mode)), before_c, mode, win_id)
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

local cheatsheet_content = function(mode, lines_no)
    local maps = get_mappings_for_mode(mode)
    table.sort(maps, function(m1, m2) return m1.ls < m2.ls end)
    -- A first empty line
    local result = {""}

    for i, map in ipairs(maps) do
        local line_idx = math.fmod(i - 1, lines_no) + 2
        local s = string.rep(" ", COL_PAD) .. map.ls .. " " .. ARROW .. " " .. (map.options.desc or 'No description')
        if s:len() > COL_LEN - COL_PAD then
            s = s:sub(1, COL_LEN - COL_PAD - 3) .. "..."
        else
            s = s .. string.rep(" ", COL_LEN - COL_PAD - s:len())
        end
        if result[line_idx] == nil then
            result[line_idx] = string.rep(" ", WIN_PAD)
        end
        result[line_idx] = result[line_idx] .. s
    end

    for i, line in ipairs(result) do
        result[i] = line .. string.rep(" ", WIN_PAD)
    end

    table.insert(result, "")
    local footer = "<esc> <C-c> " .. ARROW .. " Cancel"
    local spaces = math.ceil((vim.o.columns - math.ceil(footer:len())) / 2)
    local pads = string.rep(" ", spaces)
    table.insert(result, pads .. footer .. pads)

    return result
end

local create_window = function(mode)
    local current_win = vim.api.nvim_get_current_win()
    local cols = math.floor((vim.o.columns - (WIN_PAD * 2)) / COL_LEN)
    local height = math.ceil(#get_mappings_for_mode(mode) / cols)
    azul.suspend()
    local buf = vim.api.nvim_create_buf(false, true)
    local win_id = vim.api.nvim_open_win(buf, true, {
        width = vim.o.columns, height = height + 4, col = 0, row = vim.o.lines - height - 5,
        focusable = false, zindex = 500, border = 'none', relative = 'editor', style = 'minimal',
    })
    vim.filetype.add({
        filename = {
            azul_cheatsheet_window = 'azul_cheatsheet',
        }
    })
    vim.api.nvim_set_option_value('winhighlight', 'Normal:Identifier', {scope = 'local', win = win_id})
    vim.api.nvim_set_option_value('filetype', 'azul_cheatsheet', {buf = buf})
    vim.api.nvim_command("syn match AzulCheatsheetArrow '" .. ARROW .. "'")
    vim.api.nvim_set_current_win(current_win)
    vim.api.nvim_buf_set_lines(buf, 0, height + 3, false, cheatsheet_content(mode, height))
    azul.resume()
    return win_id
end

local restore_previous_mappings = function(mode, modifier)
    vim.api.nvim_del_keymap('t', modifier)
    vim.api.nvim_del_keymap(mode, '<esc>')
    vim.api.nvim_del_keymap(mode, '<C-c>')
    if mappings.modifier ~= nil then
        restore_map('t', modifier, mappings.modifier)
    end
    if mappings.esc ~= nil then
        restore_map(mode, '<esc>', mappings.esc)
    end
    if mappings.cc ~= nil then
        restore_map(mode, '<C-c>', mappings.cc)
    end
end

local unmap_all = function(mode, modifier)
    restore_previous_mappings(mode, modifier)
    for _, m in ipairs(get_mappings_for_mode(mode)) do
        local cmd = m.real_mode .. 'unmap ' .. m.ls
        local result = pcall(function() vim.api.nvim_command(cmd) end)
        if not result then
            print(cmd .. " failed")
        end
    end
end

local save_current_mappings = function(mode, modifier)
    mappings.modifier = find_map(modifier:upper(), 't')
    mappings.cc = find_map('<C-C>', mode)
    mappings.esc = find_map('<Esc>', mode)
end

local cancel_cheatsheet = function(mode, modifier)
    close_window(win_id)
    unmap_all(mode, modifier)
end

local set_cancel_shortcut = function(which, mode, modifier)
    vim.api.nvim_set_keymap(mode, which, '', {
        callback = function()
            cancel_cheatsheet(mode, modifier)
        end
    })
end

local map_all = function(mode, modifier)
    save_current_mappings(mode, modifier)
    vim.api.nvim_set_keymap('t', modifier, '', {
        callback = function()
            azul.send_to_current(modifier, true)
            cancel_cheatsheet(mode, modifier)
        end
    })
    set_cancel_shortcut('<esc>', mode, modifier)
    set_cancel_shortcut('<C-c>', mode, modifier)
    for _, m in ipairs(get_mappings_for_mode(mode)) do
        vim.api.nvim_set_keymap(mode, m.ls, '', {
            callback = function()
                unmap_all(mode, modifier)
                select(m, mode, win_id)
            end,
            desc = m.desc,
        })
    end
end

azul.on('ModifierTrigger', function(args)
    local mode = args[1]
    local modifier = args[2]
    win_id = create_window(mode)
    if cfg.default_config.options.blocking_cheatsheet then
        vim.fn.timer_start(0, function()
            wait_input(mode, win_id)
        end)
    else
        map_all(mode, modifier)
    end
end)

return M
