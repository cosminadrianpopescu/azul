local core = require('core')
local funcs = require('functions')
local EV = require('events')
local H = require('history')
local FILES = require('files')
local TABS = require('tab_vars')
local options = require('options')
local F = require('floats')
local R = require('remote')

local record_undo = true
local undo_list = {}
local M = {}

local restore_lines = function(buf, rec)
    if rec.term.remote_info ~= nil then
        return
    end
    local lines = (rec and rec.lines) or {}
    local i = #lines
    while i > 1 do
        if lines[i] == '' then
            table.remove(lines, i)
            i = i - 1
        else
            i = 0
        end
    end
    if #lines == 0 or options.undo_restore_cmd == nil or options.undo_restore_cmd == '' then
        return
    end
    local file = os.tmpname()
    FILES.write_file(file, funcs.join(lines, '\n'))
    vim.defer_fn(function()
        core.send_to_buf(buf, options.undo_restore_cmd .. ' ' .. file .. '<cr>', true)
        vim.defer_fn(function()
            os.remove(file)
        end, 200)
    end, 200)
end

local finish = function()
    core.start_updating_titles()
    EV.trigger_event('UndoFinished')
end

local find_create = function(pane_id, tab_id)
    for _, h in ipairs(funcs.reverse(H.get_history())) do
        if h.tab_id == tab_id and h.to == pane_id then
            return h
        end
    end

    return nil
end

local undo_tab = function(rec)
    EV.single_shot('PaneChanged', function(args)
        core.copy_terminal_properties(rec.term, args[1])
        vim.defer_fn(function()
            for k, _ in pairs(rec.tab_vars) do
                TABS.set_var(0, k, rec.tab_vars[k])
            end

            restore_lines(args[1].buf, rec)
            finish()
        end, 1)
    end)
    core.stop_updating_titles()
    if rec.term.tab_page ~= 1 then
        vim.api.nvim_command('tabn' .. (rec.term.tab_page - 1))
        vim.api.nvim_command('tabnew')
    else
        vim.api.nvim_command('0tabnew')
    end
    core.open(vim.fn.bufnr('%'), {cwd = rec.term.cwd, remote_command = R.get_remote_command(rec.term.remote_info)})
end

local undo_split = function(rec)
    local t = funcs.term_by_panel_id(rec.create.from, core.get_terminals())
    if t == nil then
        finish()
        EV.error("The terminal from which to split could not be found")
    end
    EV.single_shot('PaneChanged', function(args)
        core.copy_terminal_properties(rec.term, args[1], true)
        vim.defer_fn(function()
            restore_lines(args[1].buf, rec)
            local history = H.get_history()
            if #history > 0 then
                history[#history].to = rec.create.to
            end
            finish()
        end, 1)
    end)
    core.select_pane(t.buf)
    core.split(rec.create.params[1], R.get_remote_command(rec.term.remote_info))
end

local undo_float = function(rec)
    EV.single_shot('FloatOpened', function(args)
        core.copy_terminal_properties(rec.term, args[1])
        restore_lines(args[1].buf, rec)
        finish()
    end)
    core.stop_updating_titles()
    F.open_float({
        group = rec.term.group, win_config = rec.term.win_config, remote_command = R.get_remote_command(rec.term.remote_info),
        cwd = rec.term.cwd,
    })
end

EV.persistent_on('HistoryChanged', function(args)
    local el = args[1]
    if el.operation ~= 'close' or not record_undo or #core.get_terminals() <= 1 then
        return
    end
    local t = core.term_by_buf_id(el.buf)
    local lines = vim.api.nvim_buf_get_lines(el.buf, 0, -1, false)
    local create = find_create(el.from, el.tab_id)
    local tab_vars = {}
    if (create and create.operation) == 'create' then
        local tab_id = t.vim_tab_id
        tab_vars = {
            vesper_placeholders = TABS.get_var(tab_id, 'vesper_placeholders'),
            vesper_tab_title_overriden = TABS.get_var(tab_id, 'vesper_tab_title_overriden'),
            vesper_tab_title = TABS.get_var(tab_id, 'vesper_tab_title'),
            float_group = TABS.get_var(tab_id, 'float_group'),
        }
    end
    table.insert(undo_list, {
        term = t,
        is_float = false,
        history = el,
        lines = lines,
        create = create,
        tab_vars = tab_vars,
    })
end)

EV.persistent_on('FloatsHistoryChanged', function(args)
    local el = args[1]
    if el.operation ~= 'close' or not record_undo then
        return
    end
    local t = el.term
    local lines = vim.api.nvim_buf_get_lines(t.buf, 0, -1, false)
    table.insert(undo_list, {
        term = t,
        is_float = true,
        lines = lines,
    })
end)

M.debug = function()
    print("UNDO LIST IS " .. vim.inspect(undo_list))
end

M.undo = function()
    local rec = table.remove(undo_list, #undo_list)
    if rec == nil then
        print("Nothing to undo")
        return
    end
    rec.term.remote_info = rec.term._remote_info
    if rec.is_float then
        return undo_float(rec)
    elseif (rec and rec.create and rec.create.operation) == 'create' then
        return undo_tab(rec)
    elseif (rec and rec.create and rec.create.operation) == 'split' then
        return undo_split(rec)
    end
end

EV.persistent_on('LayoutRestoringStarted', function()
    record_undo = false
end)

EV.persistent_on('LayoutRestored', function()
    record_undo = true
end)

return M
