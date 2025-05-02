local cmd = vim.api.nvim_create_autocmd
local FILES = require('files')
local funcs = require('functions')
local azul = require('azul')

local get_disconnected_content = function(t)
    local content = {
        "This buffer is connected remotely to ",
        t.remote_command,
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
        local t = funcs.find(function(t) return (t.win_id or '') .. '' == ev.file end, azul.get_terminals())
        if t == nil or t.remote_command == nil or azul.remote_state(t) ~= 'disconnected' or t.win_id == nil then
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
    vim.api.nvim_set_option_value('filetype', 'AzulRemoteTerm', {buf = t.buf})
    t.term_id = nil
    vim.api.nvim_buf_delete(old_buf, {force = true})
    -- vim.api.nvim_buf_set_keymap(t.buf, 't', 'r', '', {
    --     callback = function()
    --         azul.remote_reconnect(t)
    --     end
    -- })
    -- vim.api.nvim_buf_set_keymap(t.buf, 't', 'q', '', {
    --     callback = function()
    --         -- t.remote_command = nil
    --         azul.remote_quit(t)
    --     end
    -- })
end

azul.persistent_on('RemoteDisconnected', function(args)
    remote_disconnected(args[1])
end)
