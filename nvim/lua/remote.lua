local FILES = require('files')
local funcs = require('functions')
local azul = require('azul')

local remote_disconnected = function(t)
    local content = "This buffer is connected remotely to " .. t.remote_command .. ".\n\nThe remote connection was lost\n\n\t[q] quit this terminal\n\t[r] try to reconnect\n"
    local file = os.tmpname()
    FILES.write_file(file, content)
    local opts = {
        cdw = vim.fn.getcwd(),
        env = {
            EDITOR = os.getenv('EDITOR'),
            VIM = '',
            VIMRUNTIME='',
        },
        on_exit = function()
            if FILES.exists(file) then
                os.remove(file)
            end
        end
    }
    local old_buf = t.buf
    t.buf = vim.api.nvim_create_buf(true, false)
    if t.win_id ~= nil then
        vim.api.nvim_win_set_buf(t.win_id, t.buf)
    end
    vim.api.nvim_buf_call(t.buf, function()
        vim.inspect("OPEN EDITOR")
        vim.fn.termopen({os.getenv('EDITOR'), file}, opts)
    end)
    t.term_id = funcs.safe_get_buf_var(t.buf, 'terminal_job_id')
    vim.api.nvim_buf_delete(old_buf, {force = true})
    vim.api.nvim_buf_set_keymap(t.buf, 't', 'r', '', {
        callback = function()
            azul.remote_reconnect(t)
        end
    })
    vim.api.nvim_buf_set_keymap(t.buf, 't', 'q', '', {
        callback = function()
            -- t.remote_command = nil
            azul.remote_quit(t)
        end
    })
end

azul.persistent_on('RemoteDisconnected', function(args)
    remote_disconnected(args[1])
end)
