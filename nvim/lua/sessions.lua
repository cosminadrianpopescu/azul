-- local from_entry = require "telescope.from_entry"
local azul = require('azul')
local sets = require('telescope.actions.set')
local actions = require('telescope.actions')
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local previewers = require('telescope.previewers')
local conf = require("telescope.config").values
-- local sorters = require "telescope.sorters"

local _sessions = {}

local split = function(s, delimiter)
    local result = {};
    for match in (s..delimiter):gmatch("(.-)"..delimiter) do
        table.insert(result, match);
    end
    return vim.tbl_filter(function(x) return x ~= '' end, result);
end

local run_process = function(cmd)
    local x = io.popen(cmd)
    local result = split(x:read('*all'), '\n')
    x:close()
    return result
end

local run_in_instance = function(session, what)
    vim.fn.jobstart(os.getenv("AZUL_NVIM_EXE") .. " --remote-send \"<C-s>n:lua require('azul')." .. what .. "()<cr>i\" --server /tmp/azul/" .. session)
    -- run_process(os.getenv("AZUL_NVIM_EXE") .. " --remote-send \"<C-s>n:lua require('azul')." .. what .. "()<cr>i\" --server /tmp/azul/" .. session)
end

local act_close = actions.close
actions.close = function(bufnr)
    act_close(bufnr)
    local entry = require('telescope.actions.state').get_selected_entry()
    vim.fn.jobstart(os.getenv("AZUL_PREFIX") .. '/bin/azul 0 0 ' .. entry.value)
    azul.resume()
    for _, s in ipairs(vim.tbl_filter(function(x) return x.buf ~= nil and vim.api.nvim_buf_is_valid(x.buf) end, _sessions)) do
        if s.value ~= os.getenv("AZUL_SESSION") then
            vim.fn.jobstart(os.getenv("AZUL_PREFIX") .. '/bin/azul 0 0 ' .. s.value)
        end
        for _, info in ipairs(vim.fn.getbufinfo(s.buf)) do
            if info.variables ~= nil and info.variables['terminal_job_id'] ~= nil then
                vim.fn.chanclose(info.variables['terminal_job_id'])
            end
        end
    end
end

sets.select = function(bufnr)
    local entry = require('telescope.actions.state').get_selected_entry()
    actions.close(bufnr)
    if entry.session ~= nil then
        local processes = run_process("ps ax | grep -E \"abduco.*-e[^\\\\-]+-a[ ]+" .. os.getenv("AZUL_SESSION") .. "$\"")
        for _, proc in ipairs(processes) do
            local p = proc:gsub("^([^ ]+) .*$", "%1")
            os.execute("echo '" .. entry.value .. "' > /tmp/azul/" .. os.getenv("AZUL_SESSION") .. "-session")
            if os.getenv("AZUL_XDOTOOL_EXE") ~= nil then
                os.execute(os.getenv("AZUL_XDOTOOL_EXE") .. " keydown ctrl keydown q keyup ctrl keyup q")
            else
                os.execute("kill -15 " .. p)
            end
            -- vim.fn.timer_start(100, function()
            --     restore_splits(entry.value)
            -- end)
        end
    elseif entry.terminal then
        if azul.is_float(entry.terminal) then
            azul.show_floats(entry.terminal.group or nil)
        else
            local tab = vim.api.nvim_win_get_tabpage(entry.terminal.win_id)
            vim.api.nvim_command('tabn ' .. tab)
        end
    end
end

require('telescope').setup{
    defaults = {
        mappings = {
            i = {
                ["<C-n>"] = require('telescope.actions').cycle_history_next,
                ["<C-p>"] = require('telescope.actions').cycle_history_prev,
                ["<C-b>"] = require('telescope.actions').results_scrolling_up,
                ["<C-f>"] = require('telescope.actions').results_scrolling_down,
                ["<C-k>"] = require('telescope.actions').move_selection_previous,
                ["<C-j>"] = require('telescope.actions').move_selection_next,
                ["<C-c>"] = require('telescope.actions').close,
            },
            n = {
                ["<C-b>"] = require('telescope.actions').results_scrolling_up,
                ["<C-f>"] = require('telescope.actions').results_scrolling_down,
                ["p"] = require('telescope.actions.layout').toggle_preview,
                ["<C-c>"] = require('telescope.actions').close,
                ["<C-n>"] = require('telescope.actions').cycle_history_next,
                ["<C-p>"] = require('telescope.actions').cycle_history_prev,
            }
        },
    },
}
local sessions_list = function(opts)
    azul.suspend()
    local sessions = run_process(os.getenv("AZUL_ABDUCO_EXE"))
    table.remove(sessions, 1)
    pickers.new(opts, {
        prompt_title = "Sessions",
        cache_picker = false,
        finder = finders.new_table {
            results = sessions,
            entry_maker = function(entry)
                local value = entry:gsub('^.*\t(.*)$', '%1')
                local valid = value ~= os.getenv("AZUL_SESSION")
                if valid and opts.select_filter ~= nil then
                    valid = opts.select_filter(value)
                end
                local s = {
                    value = value, valid = valid,
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
                    os.getenv("AZUL_PREFIX") .. "/bin/azul",
                    vim.api.nvim_win_get_width(status.preview_win),
                    vim.api.nvim_win_get_height(status.preview_win),
                    entry.value,
                    "true"
                }
            end,
        }),
    }):find()
end

local term_select = function(opts)
    azul.suspend()
    opts = opts or {}

    pickers.new(opts, {
        prompt_title = "Tabs",
        cache_picker = false,
        finder = finders.new_table {
            results = azul.get_terminals(),
            entry_maker = function(t)
                local info = vim.fn.getbufinfo(t.buf)[1]
                local name = (info.variables and info.variables.term_title) or info.name
                local s = {
                    value = name, valid = true,
                    ordinal = name, display = ((azul.is_float(t) and "Floating: ") or ("Tab " .. vim.api.nvim_win_get_tabpage(t.win_id) .. ": ")) .. name, terminal = t,
                }
                return s
            end
        },
        sorter = conf.generic_sorter({}),
        previewer = previewers.new_buffer_previewer {
            title = "Term Preview",
            keep_last_buf = true,
            define_preview = function(self, entry, _)
                vim.fn.timer_start(100, function()
                    vim.api.nvim_win_set_buf(self.state.winid, entry.terminal.buf)
                end)
            end,
        },
        default_selection_index = 1,
    }):find()
end
return {
    sessions_list = sessions_list,
    term_select = term_select,
}
