-- local from_entry = require "telescope.from_entry"
local azul = require('azul')
local sets = require('telescope.actions.set')
local actions = require('telescope.actions')
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local previewers = require('telescope.previewers')
local conf = require("telescope.config").values
local make_entry = require "telescope.make_entry"
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
    print("CLOSING")
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

-- local floats_list = function(opts)
--     pickers.new(opts, {
--         prompt_title = "Floats",
--         cache_picker = false,
--         finder = finders.new_table {
--             results = {"demo", "demo2"},
--             entry_maker = opts.entry_maker or function(entry)
--                 return {value = entry, valid = true, ordinal = entry, display = entry}
--             end,
--         },
-- 
--         previewer = previewers.new_buffer_previewer({
--             title = "Float preview",
--             define_preview = function(self, entry)
--                 local t = azul.get_terminals()[2]
--                 -- print(vim.inspect(vim.api.nvim_win_get_config(0)))
--                 -- vim.api.nvim_open_win(t.buf, true, vim.api.nvim_win_get_config(0))
--                 vim.fn.timer_start(100, function()
--                     vim.api.nvim_win_set_buf(self.state.winid, t.buf)
--                 end)
--             end,
--         }),
--     }):find()
-- end

local term_select = function(opts)
    azul.suspend()
    opts = opts or {}
    local bufnrs = vim.tbl_map(function(x) return x.buf end, azul.get_terminals())

    local buffers = {}
    for _, bufnr in ipairs(bufnrs) do
        local flag = bufnr == vim.fn.bufnr "" and "%" or (bufnr == vim.fn.bufnr "#" and "#" or " ")

        local element = {
            bufnr = bufnr,
            flag = flag,
            info = vim.fn.getbufinfo(bufnr)[1],
        }

        table.insert(buffers, element)
    end

    local max_bufnr = math.max(unpack(bufnrs))
    opts.bufnr_width = #tostring(max_bufnr)

    pickers.new(opts, {
        prompt_title = "Tabs",
        cache_picker = false,
        finder = finders.new_table {
            results = buffers,
            entry_maker = opts.entry_maker or make_entry.gen_from_buffer(opts),
        },
        -- previewer = conf.grep_previewer(opts),
        previewer = previewers.new_buffer_previewer {
            title = "Tab Preview",
            keep_last_buf = true,
            define_preview = function(self, entry, status)
                vim.fn.timer_start(100, function()
                    vim.api.nvim_win_set_buf(self.state.winid, entry.bufnr)
                end)
                -- print("entry is")
                -- print(vim.inspect(entry))
                -- print(vim.inspect(self.state))

                -- local lines = vim.api.nvim_buf_get_lines(entry.bufnr, 0, -1, false)
                -- vim.api.nvim_buf_set_lines(self.state.bufnr, 0, -1, true, lines)
                -- vim.fn.timer_start(1, function()
                --     local idx = #lines
                --     for i = #lines, 1, -1 do
                --         if lines[i] ~= '' then
                --             idx = i
                --             break
                --         end
                --     end
                --     vim.api.nvim_win_set_cursor(self.state.winid, {idx, 0})
                --     vim.api.nvim_set_option_value('filetype', 'bash', {buf = self.state.bufnr})
                -- end)
            end,
        },
        default_selection_index = 1,
    }):find()
end
return {
    sessions_list = sessions_list,
    term_select = term_select,
}
