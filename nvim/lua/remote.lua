local cmd = vim.api.nvim_create_autocmd
local funcs = require('functions')
local core = require('core')
local EV = require('events')
local F = require('floats')
local FILES = require('files')
local MAP = require('mappings')
local options = require('options')

local M = {}

local current_terminal = nil
local current_mode = nil

local get_provider = nil

local get_sock_name = function(info)
    if info == nil then
        return nil
    end
    return os.getenv('VESPER_RUN_DIR') .. '/' .. info.uid .. '-sock'
end

local send_to_provider = function(t, cmd, opts)
    if t == nil or t.remote_info == nil then
        return
    end
    local info = t.remote_info
    if info.host ~= nil and info.host ~= '' then
        cmd = 'ssh -oControlPath=' .. get_sock_name(info) .. ' ' .. info.host .. ' "' .. string.gsub(cmd, '"', '\\"') .. '"'
    end
    if opts ~= nil then
        vim.fn.jobstart(cmd, opts)
    else
        vim.fn.jobstart(cmd)
    end
end

--- @class profile_options
--- @field type string The remote provider type
--- @field host? string The host
--- @field bin? string The binary to be executed on the host via ssh

local remote_profiles = {}

local get_scrollback = function(t, local_cmd, callback)
    local opts = {
        on_stdout = function(_, data, _)
            local i = #data
            while data[i] == '' do
                table.remove(data, i)
                i = i - 1
            end
            callback(table.concat(data or {}, "\n"))
        end,
        stdout_buffered = true,
    }

    send_to_provider(t, local_cmd, opts)
end

local get_scrollback_local = function(t, callback)
    callback(core.fetch_scrollback(t))
end

local providers = {
    vesper = {
        cmd_template = '#bin# -a #session_id# -m',
        get_scrollback = function(t, callback)
            local local_cmd = t.remote_info.bin .. ' -v ' .. '"VesperDumpScrollback /tmp/' .. t.remote_info.uid .. '" -a ' .. t.remote_info.uid .. ' && cat /tmp/' .. t.remote_info.uid
            get_scrollback(t, local_cmd, callback)
        end,
    },
    tmux = {
        cmd_template = '#bin# -2 -f ' .. os.getenv('VESPER_PREFIX') .. '/share/vesper/provider-configs/tmux.conf new-session -A -s #session_id#',
        get_scrollback = function(t, callback)
            local local_cmd = t.remote_info.bin .. ' capture-pane -pS - -t ' .. t.remote_info.uid
            get_scrollback(t, local_cmd, callback)
        end,
    },
    zellij = {
        cmd_template = '#bin# options --no-pane-frames --session-name #session_id# --attach-to-session true',
        get_scrollback = function(t, callback)
            local local_cmd = t.remote_info.bin .. ' --session ' .. t.remote_info.uid .. ' action dump-screen --full /tmp/' .. t.remote_info.uid .. ' && cat /tmp/' .. t.remote_info.uid
            get_scrollback(t, local_cmd, callback)
        end
    },
    dtach = {
        cmd_template = "#bin# -A #session_id# #shell#",
        get_scrollback = get_scrollback_local,
    },
    abduco = {
        cmd_template = "#bin# -A #session_id# #shell#",
        get_scrollback = get_scrollback_local,
    },
    screen = {
        cmd_template = '#bin# -h 2000 -R #session_id#',
        get_scrollback = function(t, callback)
            local local_cmd = t.remote_info.bin .. ' -S ' .. t.remote_info.uid .. ' -X hardcopy -h /tmp/' .. t.remote_info.uid .. ' && sleep 0.1 && cat /tmp/' .. t.remote_info.uid
            get_scrollback(t, local_cmd, callback)
        end,
    }
}

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
    local p = '([a-z]+)://([^/]+)/?(.*)$'
    if connection == nil and remote_profiles[connection] == nil then
        return nil
    end
    local proto, host, bin
    if not string.match(connection, p) then
        proto = remote_profiles[connection].type
        host = remote_profiles[connection].host
        bin = remote_profiles[connection].bin
    else
        proto, host, bin = string.gmatch(connection, p)()
    end
    if bin == nil or bin == '' then
        bin = host
        host = nil
    end
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
        EV.error('The providers ' .. info.proto .. 'does not contain a command template')
        return nil
    end

    local result = string.gsub(provider.cmd_template, '#bin#', info.bin):gsub('#session_id#', info.uid):gsub('#shell#', options.shell)

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
        core.user_input({prompt = "Please enter a remote connection or a profile name:"}, function(result)
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
    parse_remote_connection(force, function(info)
        core.split(dir, M.get_remote_command(info))
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

EV.persistent_on('ModeChanged', function(args)
    current_mode = args[2]
    if current_mode == 'c' or current_terminal == nil or current_terminal.remote_info == nil or funcs.remote_state(current_terminal) == 'disconnected' then
        return
    end
    local enter_scroll = (options.workflow == 'tmux' and args[1] == 'M' and args[2] == 'n')
        or ((options.workflow == 'vesper' or options.workflow == 'zellij') and args[1] == 'a' and args[2] == 'n')


    if enter_scroll then
        local term_id = current_terminal.term_id
        vim.fn.timer_start(10, function()
            if current_mode == 'n' and current_terminal.term_id == term_id then
                M.remote_enter_scroll_mode()
            end
        end)
    end
end)

EV.persistent_on('RemoteDisconnected', function(args)
    remote_disconnected(args[1])
end)

EV.persistent_on('PaneChanged', function(args)
    current_terminal = args[1]
end)

M.remote_enter_scroll_mode = function()
    local t = core.get_current_terminal()
    local provider = get_provider(t.remote_info)
    if t.term_id == nil or provider == nil then
        return
    end

    provider.get_scrollback(t, function(data)
        local f = '/tmp/scroll-' .. os.getenv('VESPER_SESSION') .. '-' .. t.panel_id
        FILES.write_file(f, data)
        local file_type = vim.fn.substitute(options.shell or vim.o.shell, "\\v^.*\\/([^\\/]+)$", "\\1", "g")
        core.override_terminal(t, {
            os.getenv('VESPER_NVIM_EXE'), '--clean', '-u',
            os.getenv('VESPER_PREFIX') .. '/share/vesper/provider-configs/nvim.lua', f,
            '-n', '--cmd', 'set filetype=' .. file_type
        }, function()
            os.remove(f)
            core.resume()
            core.enter_mode('t')
        end)
        core.suspend()
        EV.trigger_event('RemoteStartedScroll', {t})
    end)
end

M.remote_exit_scroll_mode = function()
    local t = core.get_current_terminal()
    if t.term_id == nil then
        return
    end
    local provider = get_provider(t.remote_info)

    if provider.scroll_end == nil then
        return
    end

    if t.is_scroll == nil and type(provider.scroll_end) ~= 'function' then
        return
    end

    if type(provider.scroll_end) == 'function' then
        provider.scroll_end(t)
    else
        t.is_scroll = nil
        core.send_to_current(provider.scroll_end, true)
    end
    EV.trigger_event('RemoteEndedScroll', {t})
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

--- registers a new remote profile
--- @param name string The profile name
--- @param opts profile_options The profile options
M.register_remote_profile = function(name, opts)
    remote_profiles[name] = opts
end

MAP.add_key_parser(function(key)
    if current_mode == 'c' or vim.fn.mode() == 'c' or current_terminal == nil or current_terminal.remote_info == nil then
        return false
    end

    if funcs.remote_state(current_terminal) == 'disconnected' and vim.fn.mode() == 'n' and (key == 'q' or key == 'r') then
        pcall(function()
            if key == 'q' then
                M.remote_quit(current_terminal)
            else
                M.remote_reconnect(current_terminal)
            end
        end)
        return true
    end

    return false
end)

return M
