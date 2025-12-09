local cmd = vim.api.nvim_create_autocmd
local core = require('core')
local win_buffer = nil
local win_id = nil
local EV = require('events')
local options = require('options')
local funcs = require('functions')
local key_parser_id = nil
local MAP = require('mappings')

local welcome_content = function()
    local result = {
        "",
        "",
        "Welcome to Vesper! Your first session is now running.",
        "",
        "Here are the 3 essentials to get you started:",
        "",
        "1. The prefix key",
        "All commands start with <Ctrl>+<a>. Press it, release, then the command key.",
        "",
        "2. Pane management",
        "<Prefix> then <s>  (Change into split mode)",
        "then <j>  (Split Vertically)",
        "then <h>  (Split Horizontally)",
        "<Prefix> then <p>  (Change into pane select mode)",
        "then h/j/k/l (Navigate Panes)",
        "",
        "3. Session Control",
        "<Prefix> then <d>  (Detach and keep running)",
        "In your main shell, run `vesper -a <session-name>` to return.",
        "",
        "Press <Esc> or <q> to close. This message will not appear again.",
        "",
        "",
    }

    for i, _ in pairs(result) do
        if result[i] ~= "" then
            local pad = math.floor((100 - string.len(result[i])) / 2)
            local spaces = string.rep(" ", pad)
            result[i] = spaces .. result[i] .. spaces
        end
    end

    return result
end

local get_win_config = function()
    local content = welcome_content()
    local f1 = math.ceil(vim.o.columns / 10)
    local w = vim.o.columns - f1 * 4
    local h = #content
    local x = f1 * 2
    local y = math.ceil((vim.o.lines - h) / 2)
    return {
        width = w, height = h, col = x, row = y, focusable = false, zindex = 500,
        border = 'rounded', relative = 'editor', style = 'minimal',
    }
end

local create_window = function()
    local current_win = vim.api.nvim_get_current_win()
    core.suspend()
    win_buffer = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_lines(win_buffer, 0, -1, false, welcome_content())
    win_id = vim.api.nvim_open_win(win_buffer, false, get_win_config())
    vim.filetype.add({
        filename = {
            vesper_cheatsheet_window = 'vesper_welcome',
        }
    })
    vim.api.nvim_set_option_value('winhighlight', 'Normal:Identifier', {scope = 'local', win = win_id})
    vim.api.nvim_set_option_value('filetype', 'vesper_welcome', {buf = win_buffer})
    vim.api.nvim_set_current_win(current_win)
    core.resume()
end

local update_config_ini = function()
    options.show_welcome_message = false
    local files = require('files')
    local path = files.config_dir .. '/config.ini'
    if not files.exists(path) then
        files.write_file(path, '[Options]\n\nshow_welcome_message = false', true)
        return
    end

    local content = files.read_file(path)
    if content then
        if content:match('\n[^#\n]*show_welcome_message') then
            content = content:gsub('(\n[^#\n]*)show_welcome_message%s*=%s*true', '%1show_welcome_message = false')
        else
            content = content:gsub('(%[Options%][^\n]*\n)', '%1\nshow_welcome_message = false\n')
        end
        files.write_file(path, content, true)
    end
end

local key_parser = function(key)
    if not funcs.compare_shortcuts('<esc>', key) and not funcs.compare_shortcuts('q', key) then
        return false
    end

    funcs.safe_close_window(win_id)
    vim.fn.timer_start(1, function()
        update_config_ini()
    end)
    win_id = nil
    if key_parser_id ~= nil then
        MAP.remove_key_parser(key_parser_id)
    end
    key_parser_id = nil
    return true
end

EV.persistent_on('VesperStarted', function()
    if not options.show_welcome_message or funcs.is_marionette() then
        return
    end
    key_parser_id = MAP.add_key_parser(key_parser)

    create_window()
end)

cmd({'TabEnter', 'WinResized', 'VimResized'}, {
    pattern = "*", callback = function()
        if win_id == nil then
            return
        end

        vim.api.nvim_win_set_config(win_id, get_win_config())
    end
})
