-- local from_entry = require "telescope.from_entry"
local core = require('core')
local ERRORS = require('error_handling')
local CMDS = require('commands')
local split = require('split')
local funcs = require('functions')
local F = require('floats')

local safe, _ = pcall(function()
    require('telescope')
end)
if not safe then
    return {}
end
local sets = require('telescope.actions.set')
local actions = require('telescope.actions')
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local previewers = require('telescope.previewers')
local conf = require("telescope.config").values

local _sessions = {}
local commands_mru = {}

local get_command_args = function(command, idx, args_list, callback, me)
    local desc = CMDS.param_desc(command, idx)
    if desc == nil or desc == '' then
        callback(args_list)
        return
    end

    core.user_input({prompt = command .. " [" .. idx .. "/" .. CMDS.command_params_length(command) .. "]", title = desc, completion = "file"}, function(value)
        if value == nil then
            callback(nil)
            return
        end
        table.insert(args_list, value)
        me(command, idx + 1, args_list, callback, me)
    end, true)
end

sets.select = function(bufnr)
    local entry = require('telescope.actions.state').get_selected_entry()
    actions.close(bufnr)
    if entry.session ~= nil then
        local f = io.open("/tmp/vesper/" .. os.getenv("VESPER_SESSION") .. "-session", "w")
        f:write(entry.value)
        f:close()
        for _, s in ipairs(vim.tbl_filter(function(x) return x.buf ~= nil and vim.api.nvim_buf_is_valid(x.buf) end, _sessions)) do
            for _, info in ipairs(vim.fn.getbufinfo(s.buf)) do
                if info.variables ~= nil and info.variables['terminal_job_id'] ~= nil then
                    vim.fn.chanclose(info.variables['terminal_job_id'])
                end
            end
        end
        core.disconnect()
    elseif entry.terminal then
        if funcs.is_float(entry.terminal) then
            F.show_floats(entry.terminal.group or nil)
        end
        core.select_pane(entry.terminal.buf)
    elseif entry.command then
        if #vim.tbl_filter(function(c) return c == entry.command.name end, commands_mru) > 0 then
            for i, _ in pairs(commands_mru) do
                if commands_mru[i] == entry.command.name then
                    table.remove(commands_mru, i)
                    break
                end
            end
        end

        table.insert(commands_mru, 1, entry.command.name)
        get_command_args(entry.command.name, 1, {}, function(args)
            if args == nil then
                return
            end
            vim.api.nvim_command(entry.command.name .. ' ' .. table.concat(args, ' '))
        end, get_command_args)
    end
end

require('telescope').setup{
    -- defaults = {
    --     mappings = {
    --         i = {
    --             ["<C-n>"] = require('telescope.actions').cycle_history_next,
    --             ["<C-p>"] = require('telescope.actions').cycle_history_prev,
    --             ["<C-b>"] = require('telescope.actions').results_scrolling_up,
    --             ["<C-f>"] = require('telescope.actions').results_scrolling_down,
    --             ["<C-k>"] = require('telescope.actions').move_selection_previous,
    --             ["<C-j>"] = require('telescope.actions').move_selection_next,
    --             ["<C-c>"] = require('telescope.actions').close,
    --         },
    --         n = {
    --             ["<C-b>"] = require('telescope.actions').results_scrolling_up,
    --             ["<C-f>"] = require('telescope.actions').results_scrolling_down,
    --             ["p"] = require('telescope.actions.layout').toggle_preview,
    --             ["<C-c>"] = require('telescope.actions').close,
    --             ["<C-n>"] = require('telescope.actions').cycle_history_next,
    --             ["<C-p>"] = require('telescope.actions').cycle_history_prev,
    --         }
    --     },
    -- },
}
local sessions_list = function(opts)
    if os.getenv("VESPER_SESSION") == nil then
        return
    end
    local sessions = funcs.run_process_list(os.getenv("VESPER_PREFIX") .. "/bin/vesper -l")
    pickers.new(opts, {
        prompt_title = "Sessions",
        cache_picker = false,
        finder = finders.new_table {
            results = sessions,
            entry_maker = function(entry)
                local valid = entry ~= os.getenv("VESPER_SESSION")
                if valid and opts.select_filter ~= nil then
                    valid = opts.select_filter(entry)
                end
                local s = {
                    value = entry, valid = valid,
                    ordinal = entry, display = entry, session = entry
                }

                table.insert(_sessions, s)

                return s
            end,
        },
        sorter = conf.generic_sorter({}),
        previewer = previewers.new_termopen_previewer({
            title = "Session Preview",
            get_command = function(entry, status)
                entry.buf = vim.api.nvim_win_get_buf(status.preview_win)
                return {
                    os.getenv('VESPER_PREFIX') .. '/bin/vesper', '-a', entry.value,
                }
            end,
        }),
    }):find()
end

local term_select = function(opts)
    opts = opts or {}

    pickers.new(opts, {
        prompt_title = "Tabs",
        cache_picker = false,
        finder = finders.new_table {
            results = core.get_terminals(),
            entry_maker = function(t)
                local info = vim.fn.getbufinfo(t.buf)[1]
                local name = (info.variables and info.variables.term_title) or info.name
                local s = {
                    value = name, valid = true,
                    ordinal = name, display = ((funcs.is_float(t) and "Floating: ") or ("Tab " .. vim.api.nvim_win_get_tabpage(t.win_id) .. ": ")) .. name, terminal = t,
                }
                return s
            end
        },
        sorter = conf.generic_sorter({}),
        previewer = previewers.new_buffer_previewer {
            title = "Term Preview",
            keep_last_buf = true,
            define_preview = function(self, entry, _)
                ERRORS.defer(100, function()
                    vim.api.nvim_win_set_buf(self.state.winid, entry.terminal.buf)
                end)
            end,
        },
        default_selection_index = 1,
    }):find()
end

local select_command = function(opts)
    opts = opts or {}

    local cmds = vim.tbl_deep_extend("force", {}, CMDS.list())
    local is_mru = function(c)
        return vim.tbl_contains(commands_mru, c.name)
    end
    table.sort(cmds, function(a, b)
        if not is_mru(a) and not is_mru(b) then
            return a.name < b.name
        end
        if is_mru(a) and is_mru(b) then
            return funcs.index_of(commands_mru, a.name) < funcs.index_of(commands_mru, b.name)
        end
        return vim.tbl_contains(commands_mru, a.name)
    end)

    pickers.new(opts, {
        results_title = "Vesper commands",
        cache_picker = false,
        finder = finders.new_table {
            results = cmds,
            entry_maker = function(c)
                local name = string.gsub(c.name, '^Vesper', '')
                return {
                    value = name, valid = true,
                    ordinal = name, display = name, command = c,
                }
            end
        },
        sorter = conf.generic_sorter({}),
        previewer = previewers.new_buffer_previewer {
            title = "Documentation",
            keep_last_buf = true,
            define_preview = function(self, entry, _)
                local content = split.split(entry.command.definition, '\n')
                vim.api.nvim_buf_set_lines(self.state.bufnr, 0, #content, false, content)
                vim.api.nvim_set_option_value('filetype', 'markdown', {buf = self.state.bufnr})
            end,
        },
        default_selection_index = 1,
    }):find()
end

return {
    sessions_list = sessions_list,
    term_select = term_select,
    select_command = select_command,
}
