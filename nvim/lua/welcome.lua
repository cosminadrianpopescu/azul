local cmd = vim.api.nvim_create_autocmd
local core = require('core')
local win_buffer = nil
local win_id = nil
local EV = require('events')
local options = require('options')
local funcs = require('functions')

local welcome_content = function()
    return {"Welcome to VESPER"}
end

local get_win_config = function()
    local f1 = math.ceil(vim.o.columns / 10)
    local f2 = math.ceil(vim.o.lines / 10)
    local w = vim.o.columns - f1 * 2
    local h = vim.o.lines - f2 * 2
    local x = f1
    local y = f2 - 1
    core.suspend()
    win_buffer = vim.api.nvim_create_buf(false, true)
    return {
        width = w, height = h, col = x, row = y, focusable = false, zindex = 500,
        border = 'rounded', relative = 'editor', style = 'minimal',
    }
end

local create_window = function()
    local current_win = vim.api.nvim_get_current_win()
    core.suspend()
    win_buffer = vim.api.nvim_create_buf(false, true)
    win_id = vim.api.nvim_open_win(win_buffer, true, get_win_config())
    vim.filetype.add({
        filename = {
            vesper_cheatsheet_window = 'vesper_welcome',
        }
    })
    vim.api.nvim_set_option_value('winhighlight', 'Normal:Identifier', {scope = 'local', win = win_id})
    vim.api.nvim_set_option_value('filetype', 'vesper_welcome', {buf = win_buffer})
    vim.api.nvim_set_current_win(current_win)
    vim.api.nvim_buf_set_lines(win_buffer, 0, -1, false, welcome_content())
    core.resume()
end

local update_config_ini = function()
    local files = require('files')
    local path = files.config_dir .. '/config.ini'
    if not files.exists(path) then
        files.write_file(path, '[Options]\n\nshow_welcome_message = false')
        return
    end

    local content = files.read_file(path)
    if content then
        if content:match('\n[^#\n]*show_welcome_message') then
            content = content:gsub('(\n[^#\n]*)show_welcome_message%s*=%s*true', '%1show_welcome_message = false')
        else
            content = content:gsub('(%[Options%][^\n]*\n)', '%1\nshow_welcome_message = false\n')
        end
        files.write_file(path, content)
    end
end

EV.persistent_on('VesperStarted', function()
    if not options.show_welcome_message then
        return
    end

    create_window()
    -- update_config_ini()
end)

cmd({'TabEnter', 'WinResized', 'VimResized'}, {
    pattern = "*", callback = function(ev)
        if win_id == nil then
            return
        end

        vim.api.nvim_win_set_config(win_id, get_win_config())
    end
})
