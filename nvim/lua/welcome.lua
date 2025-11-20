local core = require('core')
local win_buffer = nil
local win_id = nil
local EV = require('events')
local options = require('options')

local welcome_content = function()
    return {"Welcome to VESPER"}
end

local create_window = function()
    local current_win = vim.api.nvim_get_current_win()
    local f1 = math.ceil(vim.o.columns / 10)
    local f2 = math.ceil(vim.o.lines / 10)
    local w = vim.o.columns - f1 * 2
    local h = vim.o.lines - f2 * 2
    local x = f1
    local y = f2 - 1
    core.suspend()
    win_buffer = vim.api.nvim_create_buf(false, true)
    win_id = vim.api.nvim_open_win(win_buffer, true, {
        width = w, height = h, col = y, row = x,
        focusable = false, zindex = 500, border = 'none', relative = 'editor', style = 'minimal',
    })
    vim.filetype.add({
        filename = {
            vesper_cheatsheet_window = 'vesper_welcome',
        }
    })
    -- vim.api.nvim_set_option_value('winhighlight', 'Normal:Identifier', {scope = 'local', win = win_id})
    vim.api.nvim_set_option_value('filetype', 'vesper_welcome', {buf = win_buffer})
    vim.api.nvim_set_current_win(current_win)
    vim.api.nvim_buf_set_lines(win_buffer, 0, h + 3, false, welcome_content())
    core.resume()
end

EV.persistent_on('VesperStarted', function()
    if not options.show_welcome_message then
        return
    end

    create_window()
end)
