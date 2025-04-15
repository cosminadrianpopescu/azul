local FILES = require('files')
local funcs = require('functions')
local azul = require('azul')

local remote_disconnected = function(t)
    local old_buf = t.buf
    t.buf = vim.api.nvim_create_buf(true, true)
    if t.win_id ~= nil then
        vim.api.nvim_win_set_buf(t.win_id, t.buf)
    end
    local content = {
        "", "",
        "\tThis buffer is connected remotely to ",
        "",
        "\t" .. t.remote_command,
        "", "",
        " \tThe remote connection was lost",
        "", "",
        "\t\t[q] quit and close this pane",
        "\t\t[r] try to reconnect",
    }
    vim.api.nvim_buf_set_lines(t.buf, 0, #content, false, content)
    -- vim.api.nvim_buf_call(t.buf, function()
    --     vim.fn.termopen({os.getenv('EDITOR'), file}, opts)
    -- end)
    vim.api.nvim_set_option_value('modifiable', false, {buf = t.buf})
    vim.api.nvim_set_option_value('filetype', 'AzulRemoteTerm', {buf = t.buf})
    t.term_id = nil
    vim.api.nvim_buf_delete(old_buf, {force = true})
    funcs.log("FINISH REMOTE DISCONNECTED")
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
