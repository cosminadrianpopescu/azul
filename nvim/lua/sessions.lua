-- local from_entry = require "telescope.from_entry"
local azul = require('azul')
local actions = require('telescope.actions')
local act_close = actions.close
actions.close = function(bufnr)
    act_close(bufnr)
    azul.resume()
end
actions.select_default = function(bufnr)
    actions.close(bufnr)
    print("SELECTED")
    print(vim.inspect(bufnr))
end
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local previewers = require('telescope.previewers')
-- local conf = require("telescope.config").values
local make_entry = require "telescope.make_entry"
-- local sorters = require "telescope.sorters"

local sessions_list = function(opts)
    azul.suspend()
    pickers.new(opts, {
        prompt_title = "Sessions",
        cache_picker = false,
        finder = finders.new_table {
            results = {"demo", "demo2"},
            entry_maker = opts.entry_maker or function(entry)
                return {value = entry, valid = true, ordinal = entry, display = entry}
            end,
        },

        previewer = previewers.new_termopen_previewer({
            title = "Session Preview",
            get_command = function(entry)
                return {"abduco", "-a", "demo2"}
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
