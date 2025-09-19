local funcs = require('functions')
local core = require('core')

local win_id = nil

local function wininput(opts, on_confirm, win_opts)
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "prompt"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "azul_prompt"

    local prompt = opts.prompt or ""
    local default_text = opts.default or ""

    local deferred_callback = function(input)
        if win_id ~= nil then
            vim.api.nvim_win_close(win_id, true)
        end
        vim.defer_fn(function()
            on_confirm(input)
        end, 1)
    end

    vim.fn.prompt_setprompt(buf, '> ')
    vim.fn.prompt_setcallback(buf, deferred_callback)
    vim.fn.prompt_setinterrupt(buf, deferred_callback)

    -- set some keymaps: CR confirm and exit, ESC in normal mode to abort
    vim.keymap.set("n", "<esc>", "", {
        callback = deferred_callback,
        silent = true, buffer = buf
    })

    local default_win_opts = {
        relative = "editor",
        row = vim.o.lines / 2 - 1,
        col = vim.o.columns / 2 - 35,
        height = 1,
        focusable = true,
        style = "minimal",
        border = "rounded",
        title = prompt,
        title_pos = "center",
    }

    win_opts = vim.tbl_deep_extend("force", default_win_opts, win_opts)

    win_id = vim.api.nvim_open_win(buf, true, win_opts)
    vim.api.nvim_set_option_value('winhighlight', 'Search:None', {win = win_id})

    vim.cmd("startinsert")

    vim.defer_fn(function()
        if default_text ~= '' then
            funcs.safe_put_text_to_buffer(buf, 0, 2, default_text, function()
                vim.cmd("startinsert!") -- bang: go to end of line
            end)
        end
    end, 1)
end

vim.ui.input = function(opts, on_confirm)
    core.suspend()
    vim.fn.timer_start(1, function()
        core.resume()
    end)
    wininput(opts, function(input)
        on_confirm(input)
    end, { border = "rounded", width = 70 })
end
