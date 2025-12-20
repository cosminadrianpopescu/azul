local cmd = vim.api.nvim_create_autocmd
local funcs = require('functions')
local core = require('core')
local EV = require('events')
local F = require('floats')
local ERRORS = require('error_handling')
local MAP = require('mappings')
local options = require('options')

local M = {}

local current_terminal = nil
local current_mode = nil
local current_provider = nil
local scroll_exit_shortcuts = {}
local search_shortcuts = {}
local is_core_suspended = false
local last_key = nil
local caught_esc = false
local is_searching = false

local get_provider = nil

local suspend = function()
    is_core_suspended = true
    core.suspend()
end

local resume = function()
    is_core_suspended = false
    core.resume()
end

local get_sock_name = function(info)
    if info == nil then
        return nil
    end
    return os.getenv('VESPER_RUN_DIR') .. '/' .. info.uid .. '-sock'
end

local is_search_shortcut = function(key)
    return #vim.tbl_filter(function(s) return funcs.compare_shortcuts(s, key) end, search_shortcuts) > 0
end

local get_exit_scroll_shortcuts = function()
    local mappings = vim.tbl_filter(function(x)
        return (x.m == 'n' or x.m == 'a') and x.options ~= nil and x.options.action == 'enter_mode' and x.options.arg == 't'
    end, core.get_mode_mappings())
    local result = vim.tbl_map(function(m) return m.ls end, mappings)
    table.insert(result, 'i')
    table.insert(result, 'a')
    table.insert(result, 'A')
    table.insert(result, '<INS>')
    return result
end

local get_search_shortcuts = function()
    local mappings = vim.tbl_filter(function(x)
        return x.m == 'n' and x.options ~= nil and x.options.action == 'start_search'
    end, core.get_mode_mappings())
    return vim.tbl_map(function(m) return m.ls end, mappings)
end

local send_to_provider = function(t, cmd, opts)
    if t == nil or t.remote_info == nil then
        return
    end
    local info = t.remote_info
    if info.host ~= nil and info.host ~= '' then
        cmd = 'ssh -oControlPath=' .. get_sock_name(info) .. ' ' .. info.host .. ' ' .. cmd
    end
    if opts ~= nil then
        vim.fn.jobstart(cmd, opts)
    else
        vim.fn.jobstart(cmd)
    end
end

local send_to_vesper = function(t, vim_cmd, opts)
    send_to_provider(t, t.remote_info.bin .. ' -v ' .. vim_cmd .. ' -a ' .. t.remote_info.uid, opts)
end

local send_to_tmux = function(t, cmd, opts)
    send_to_provider(t, t.remote_info.bin .. ' ' .. cmd .. ' -t ' .. t.remote_info.uid, opts)
end

local providers = {
    vesper = {
        scroll_start = function(t)
            local opts = {
                on_exit = function()
                    core.send_to_current(last_key, true)
                end
            }
            send_to_vesper(t, 'stopinsert', (options.workflow == 'tmux' and last_key ~= ':' and opts) or nil)
        end,
        scroll_end = function(t)
            send_to_vesper(t, 'startinsert')
        end,
        search = {
            enter = '/',
            exit = {'<esc>', '<cr>', '<C-c>'}
        },
        cmd_template = '#bin# -a #session_id# -m',
    },
    tmux = {
        cmd_template = '#bin# -2 new-session -A -s #session_id#',
        scroll_start = function(t)
            local opts = {
                on_exit = function()
                    core.send_to_current(last_key, true)
                end
            }
            send_to_tmux(t, 'copy-mode', (options.workflow == 'tmux' and last_key ~= ':' and opts) or nil)
        end,
        scroll_end = '<C-c>',
    }
}

local start_searching = function()
    core.send_to_current(current_provider.search.enter, true)
    is_searching = true
end

get_provider = function(info)
    if info == nil or providers[info.proto] == nil then
        return nil
    end

    return providers[info.proto]
end

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
    local uid = funcs.uuid()
    return {
        host = host, proto = proto, bin = bin, uid = uid,
    }
end

M.get_remote_command = function(info)
    local provider = get_provider(info)
    if provider == nil then
        return nil
    end

    if provider.cmd_template == nil then
        ERRORS.throw('The providers ' .. info.proto .. 'does not contain a command template')
        return nil
    end

    local result = string.gsub(provider.cmd_template, '#bin#', info.bin):gsub('#session_id#', info.uid)

    if info.host ~= '' and info.host ~= nil then
        result = 'ssh -oControlMaster=yes -oControlPath=' .. get_sock_name(info) .. ' ' .. info.host .. " -t '" .. result .. "'"
    end
    return result
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

EV.persistent_on('ModeChanged', function(args)
    current_mode = args[2]
    if current_mode == 'c' or current_terminal == nil or current_terminal.remote_info == nil or funcs.remote_state(current_terminal) == 'disconnected' then
        return
    end
    if current_mode == 'M' then
        scroll_exit_shortcuts = get_exit_scroll_shortcuts()
        search_shortcuts = get_search_shortcuts()
    end
    local enter_scroll = (options.workflow == 'tmux' and args[1] == 'M' and args[2] == 'n')
        or ((options.workflow == 'vesper' or options.workflow == 'zellij') and args[1] == 'a' and args[2] == 'n')


    if caught_esc then
        caught_esc = false
        return
    end

    if enter_scroll then
        M.remote_enter_scroll_mode()
    end
end)

M.remote_enter_scroll_mode = function()
    local provider = get_provider(current_terminal.remote_info)
    if current_terminal.term_id == nil or provider == nil then
        return
    end

    if provider.scroll_start == nil then
        return
    end

    if type(provider.scroll_start) == 'function' then
        provider.scroll_start(current_terminal)
    else
        current_terminal.is_scroll = true
        core.send_to_current(provider.scroll_start, true)
    end
    current_provider = provider
    EV.trigger_event('RemoteStartedScroll', {current_terminal})
    core.set_key_map('n', options.scroll_to_copy, '<C-\\><C-n>', {})
    suspend()
end

M.remote_exit_scroll_mode = function(t, to_mode)
    local x = t or current_terminal
    local m = to_mode or 't'
    if x.term_id == nil or current_provider == nil then
        return
    end

    if current_provider.scroll_end == nil then
        return
    end

    if x.is_scroll == nil and type(current_provider.scroll_end) ~= 'function' and type(current_provider.scroll_start) ~= 'function' then
        return
    end

    if type(current_provider.scroll_end) == 'function' then
        current_provider.scroll_end(x)
    else
        x.is_scroll = nil
        core.send_to_current(current_provider.scroll_end, true)
    end
    current_provider = nil
    resume()
    core.remove_key_map('n', options.scroll_to_copy)
    core.enter_mode(m)
    EV.trigger_event('RemoteEndedScroll', {x})
end

M.remote_reconnect = function(t)
    if t.remote_info == nil then
        ERRORS.throw("The terminal " .. t.term_id .. " is not a remote terminal", nil)
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
        suspend()
        vim.fn.jobstop(id)
        vim.fn.timer_start(1, function()
            resume()
        end)
    end
    suspend()
    core.open(t.buf, {remote_command = M.get_remote_command(t.remote_info)})
    resume()
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
    last_key = key
    if current_mode == 'c' or vim.fn.mode() == 'c' or vim.fn.mode() == 'i' or current_terminal == nil or current_terminal.remote_info == nil then
        return false
    end

    if funcs.remote_state(current_terminal) == 'disconnected' and (key == 'q' or key == 'r') then
        pcall(function()
            if key == 'q' then
                M.remote_quit(current_terminal)
            else
                M.remote_reconnect(current_terminal)
            end
        end)
        return true
    end

    if current_mode == 'M' and funcs.compare_shortcuts('<esc>', key) then
        caught_esc = true
        return false
    end

    if current_mode == 'M' and options.workflow == 'tmux' and is_search_shortcut(key) then
        core.enter_mode('n')
        vim.fn.timer_start(1, function()
            vim.api.nvim_command('startinsert')
        end)
        return true
    end

    if current_mode ~= 'n' or current_provider == nil then
        return false
    end

    if key == ':' and vim.fn.mode() == 't' and not options.strict_scroll then
        vim.api.nvim_command('stopinsert')
        core.feedkeys(':', 't')
        M.remote_exit_scroll_mode(current_terminal, 'n')
        return true
    end

    if is_search_shortcut(key) then
        start_searching()
        return true
    end

    if is_searching and #vim.tbl_filter(function(s) return funcs.compare_shortcuts(s, key) end, current_provider.search.exit) > 0 then
        is_searching = false
        core.send_to_current(key, true)
        return true
    end

    if is_searching or #vim.tbl_filter(function(s) return funcs.compare_shortcuts(s, key) end, scroll_exit_shortcuts) == 0 then
        return false
    end

    M.remote_exit_scroll_mode()
    return true
end)

return M
