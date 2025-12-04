local cmd = vim.api.nvim_create_autocmd
local funcs = require('functions')
local core = require('core')
local EV = require('events')
local F = require('floats')
local MAP = require('mappings')

local M = {}

local current_terminal = nil

local providers = {
    vesper = {
        scroll_page_up = {'<C-b>', '<PageUp>'},
        scroll_page_down = {'<C-f>', '<PageDown>'},
        scroll_left = {'h', '<left>'},
        scroll_down = {'j', '<down>'},
        scroll_right = {'l', '<right>'},
        scroll_up = {'k', '<up>'},
    }
}

local get_disconnected_content = function(t)
    local content = {
        "This buffer is connected remotely ",
        "",
    }

    if t.remote_info.host ~= nil and t.remote_info.host ~= '' then
        table.insert(content, "    * HOST: " .. t.remote_info.host)
    end

    table.insert(content, "    * BIN: " .. t.remote_info.bin)
    table.insert(content, "    * ID: " .. t.remote_info.uid)
    table.insert(content, "")
    table.insert(content, "The remote connection was lost")
    table.insert(content, "    [q] quit and close this pane")
    table.insert(content, "    [r] try to reconnect")

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

local get_remote_info = function(connection)
    local p = '([a-z]+)://([^@]+)@?(.*)$'
    if connection == nil or not string.match(connection, p) then
        return nil
    end
    local proto, bin, host = string.gmatch(connection, p)()
    local cmd = ''
    local uid = funcs.uuid()
    if proto == 'vesper' then
        cmd = bin .. ' -a ' .. uid .. ' -m'
    elseif proto == 'dtach' then
        cmd = bin .. ' -A ' .. uid .. ' ' .. vim.o.shell
    elseif proto == 'abduco' then
        cmd = bin .. ' -A ' .. uid
    end
    if host ~= '' and host ~= nil then
        cmd = 'ssh -oControlMaster=yes -oControlPath=' .. os.getenv('VESPER_RUN_DIR') .. '/' .. uid .. ' ' .. host .. " -t '" .. cmd .. "'"
    end
    return {
        host = host, proto = proto, bin = bin, cmd = cmd, uid = uid,
    }
end

M.get_remote_command = function(info)
    if info == nil then
        return nil
    end
    local cmd = ''
    if info.proto == 'vesper' then
        cmd = info.bin .. ' -a ' .. info.uid .. ' -m'
    elseif info.proto == 'dtach' then
        cmd = info.bin .. ' -A ' .. info.uid .. ' ' .. vim.o.shell
    elseif info.proto == 'abduco' then
        cmd = info.bin .. ' -A ' .. info.uid
    end
    if info.host ~= '' and info.host ~= nil then
        cmd = 'ssh -oControlMaster=yes -oControlPath=' .. os.getenv('VESPER_RUN_DIR') .. '/' .. info.uid .. ' ' .. info.host .. " -t '" .. cmd .. "'"
    end
    return cmd
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
        local remote_info = get_remote_info(result)
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
        F.open_float({group = options.group, win_config = options.win_config, to_restore = options.to_restore, remote_command = M.get_remote_command(info)})
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
        core.open(buf, {remote_command = M.get_remote_command(info)})
    end)
end

M.create_tab_remote = function()
    M.open_remote()
end

EV.persistent_on('RemoteDisconnected', function(args)
    remote_disconnected(args[1])
end)

EV.persistent_on('PaneChanged', function(args)
    current_terminal = args[1]
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

M.remote_reconnect = function(t)
    if t.remote_info == nil then
        EV.error("The terminal " .. t.term_id .. " is not a remote terminal", nil)
        return
    end
    local old_buf = t.buf
    local id = funcs.safe_get_buf_var(t.buf, 'terminal_job_id')
    t.buf = vim.api.nvim_create_buf(false, false)
    if t.win_id ~= nil then
        vim.api.nvim_win_set_buf(t.win_id, t.buf)
    end
    vim.api.nvim_buf_delete(old_buf, {force = true})
    if id ~= nil then
        core.suspend()
        vim.fn.jobstop(id)
        vim.fn.timer_start(1, function()
            core.resume()
        end)
    end
    core.suspend()
    core.open(t.buf, {remote_command = M.get_remote_command(t.remote_info)})
    core.resume()
    EV.trigger_event('RemoteReconnected', {t})
    t.term_id = funcs.safe_get_buf_var(t.buf, 'terminal_job_id')
    core.update_titles()
end

M.remote_quit = function(t)
    t._remote_info = t.remote_info
    t.remote_info = nil
    local term_id = funcs.safe_get_buf_var(t.buf, 'terminal_job_id')
    if term_id ~= nil then
        vim.fn.jobstop(funcs.safe_get_buf_var(t.buf, 'terminal_job_id'))
    end
    EV.trigger_event('RemoteQuit', {t})
end

MAP.add_key_parser(function(key)
    if current_terminal == nil or current_terminal.remote_info == nil or funcs.remote_state(current_terminal) ~= 'disconnected' or (key ~= 'q' and key ~= 'r') then
        return false
    end
    pcall(function()
        if key == 'q' then
            M.remote_quit(current_terminal)
        else
            M.remote_reconnect(current_terminal)
        end
    end)
    return true
end)

return M
