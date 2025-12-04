local cmd = vim.api.nvim_create_autocmd
local funcs = require('functions')
local core = require('core')
local EV = require('events')
local F = require('floats')

local M = {}

local get_disconnected_content = function(t)
    local content = {
        "This buffer is connected remotely to ",
        t.remote_info.cmd,
        "",
        "The remote connection was lost",
        "    [q] quit and close this pane",
        "    [r] try to reconnect",
    }

    local max_width = 0
    for _, l in ipairs(content) do
        if string.len(l) > max_width then
            max_width = string.len(l)
        end
    end

    if max_width < t.win_config.width then
        local spaces_left = string.rep(" ", math.floor((t.win_config.width - max_width) / 2))
        for i, _ in ipairs(content) do
            content[i] = spaces_left .. content[i]
        end
    end

    if #content < t.win_config.height then
        local lines = math.floor((t.win_config.height - #content) / 2)
        for _ = 1, lines do
            table.insert(content, 1, "")
        end

        while #content < t.win_config.height do
            table.insert(content, "")
        end
    end

    return content
end

cmd({'TabEnter', 'WinResized', 'VimResized'}, {
    pattern = "*", callback = function(ev)
        local t = funcs.find(function(t) return (t.win_id or '') .. '' == ev.file end, core.get_terminals())
        if t == nil or t.remote_info == nil or funcs.remote_state(t) ~= 'disconnected' or t.win_id == nil then
            return
        end
        t.win_config = vim.api.nvim_win_get_config(t.win_id)
        local content = get_disconnected_content(t)
        vim.api.nvim_set_option_value('modifiable', true, {buf = t.buf})
        vim.api.nvim_buf_set_lines(t.buf, 0, #content, false, content)
        vim.api.nvim_set_option_value('modifiable', false, {buf = t.buf})
    end
})

local remote_disconnected = function(t)
    local old_buf = t.buf
    t.buf = vim.api.nvim_create_buf(true, true)
    if t.win_id ~= nil then
        vim.api.nvim_win_set_buf(t.win_id, t.buf)
    end
    local content = get_disconnected_content(t)
    vim.api.nvim_buf_set_lines(t.buf, 0, #content, false, content)
    -- vim.api.nvim_buf_call(t.buf, function()
    --     vim.fn.termopen({os.getenv('EDITOR'), file}, opts)
    -- end)
    vim.api.nvim_set_option_value('modifiable', false, {buf = t.buf})
    vim.api.nvim_set_option_value('filetype', 'VesperRemoteTerm', {buf = t.buf})
    t.term_id = nil
    vim.api.nvim_buf_delete(old_buf, {force = true})
    -- vim.api.nvim_buf_set_keymap(t.buf, 't', 'r', '', {
    --     callback = function()
    --         core.remote_reconnect(t)
    --     end
    -- })
    -- vim.api.nvim_buf_set_keymap(t.buf, 't', 'q', '', {
    --     callback = function()
    --         -- t.remote_info = nil
    --         core.remote_quit(t)
    --     end
    -- })
end

local parse_remote_connection = function(force, callback)
    local when_done = function(result)
        local remote_info = funcs.remote_info(result)
        if remote_info == nil then
            return
        end
        EV.single_shot('TerminalAdded', function(args)
            args[1].remote_info = remote_info
        end)
        callback(remote_info)
    end
    if force == true or not funcs.is_handling_remote() then
        core.user_input({prompt = "Please enter a remote connection:"}, function(result)
            if result == nil or result == '' then
                return
            end
            when_done(result)
        end)

        return
    end

    when_done(os.getenv('VESPER_REMOTE_CONNECTION'))
end

--- Opens a new float
--- @param force boolean If true, then always ask for the remote connection, even if the VESPER_REMOTE_CONNECTION var is set
--- @param options float_open_options The list of options for opening a float
M.open_float_remote = function(force, options)
    if options == nil then
        options = {}
    end
    parse_remote_connection(force, function(info)
        F.open_float({group = options.group, win_config = options.win_config, to_restore = options.to_restore, remote_info = info})
    end)
end

M.split_remote = function(force, dir)
    parse_remote_connection(force, function(cmd)
        core.split(dir, cmd)
    end)
end

--- Opens a new remote terminal in the current window
---
---@param force boolean If true, then always ask for the remote connection, even if the VESPER_REMOTE_CONNECTION var is set
---@param buf number The current buffer number (optional)
M.open_remote = function(force, buf)
    parse_remote_connection(force, function(info)
        core.open(buf, {remote_info = info})
    end)
end

M.create_tab_remote = function()
    M.open_remote()
end

EV.persistent_on('RemoteDisconnected', function(args)
    remote_disconnected(args[1])
end)

M.remote_enter_scroll_mode = function()
    local t = core.get_current_terminal()
    if t.term_id == nil then
        return
    end
    t.is_scroll = true
    core.send_to_current('<C-\\><C-n>', true)
end

M.remote_exit_scroll_mode = function()
    local t = core.get_current_terminal()
    if t.term_id == nil or t.is_scroll == nil then
        return
    end
    t.is_scroll = nil
    core.send_to_current('i', true)
end

return M
