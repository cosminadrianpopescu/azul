local core = require('core')
local ERRORS = require('error_handling')
local funcs = require('functions')

local safe_put_text_to_buffer = function(buf, row, col, txt, after, me)
    local safe, _ = pcall(function()
        vim.api.nvim_buf_set_text(buf, row, col, row, col, {txt})
    end)

    if not safe then
        vim.fn.timer_start(1, function()
            me(buf, row, col, txt, after, me)
        end)
    else
        after()
    end
end

local function wininput(opts, on_confirm, win_opts)
    local win_id = nil
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].buftype = "prompt"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].filetype = "vesper_prompt"

    local prompt = opts.prompt or ""
    local title = opts.title or ''
    local default_text = opts.default or ""
    local timer

    local deferred_callback = function(input)
        if timer ~= nil then
            vim.fn.timer_stop(timer)
        end
        if win_id ~= nil and vim.api.nvim_win_is_valid(win_id) then
            vim.api.nvim_win_close(win_id, true)
        end
        ERRORS.defer(1, function()
            on_confirm(input)
        end)
    end

    timer = vim.fn.timer_start(100, function()
        if win_id ~= nil and not vim.api.nvim_win_is_valid(win_id) then
            deferred_callback(nil)
        end
    end, {['repeat'] = -1})

    vim.fn.prompt_setprompt(buf, prompt .. '> ')
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
        title = title,
        title_pos = "center",
        zindex = 99
    }

    win_opts = vim.tbl_deep_extend("force", default_win_opts, win_opts)

    win_id = vim.api.nvim_open_win(buf, true, win_opts)
    vim.api.nvim_set_option_value('winhighlight', 'Search:None', {win = win_id})

    vim.cmd("startinsert")

    vim.fn.timer_start(100, function()
        if default_text ~= '' then
            safe_put_text_to_buffer(buf, 0, 2, default_text, function()
                vim.cmd("startinsert!") -- bang: go to end of line
            end, safe_put_text_to_buffer)
            -- funcs.safe_put_text_to_buffer(buf, 0, 2, default_text, function()
            --     vim.cmd("startinsert!") -- bang: go to end of line
            -- end)
        end
    end)
end

vim.ui.input = function(opts, on_confirm)
    core.suspend()
    ERRORS.defer(1, function()
        core.resume()
    end)
    wininput(opts, function(input)
        on_confirm(input)
    end, { border = "rounded", width = 70 })
end
