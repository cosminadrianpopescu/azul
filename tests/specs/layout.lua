local t = require('test-env')
local azul = require('azul')
local funcs = require('functions')

local L = {}

L.close_all_panes = function(when_done)
    if #azul.get_terminals() == 1 then
        when_done()
        return
    end

    local term = azul.get_current_terminal()
    t.single_shot('PaneChanged', function()
        L.close_all_panes(when_done)
    end)
    vim.fn.jobstop(term.term_id)
end

local file = "test.layout"

t.simulate_keys("<C-s>sljjhk", {ModeChanged = 2, PaneChanged = 5}, function()
    t.simulate_keys("<cr>", {ModeChanged = 1}, function()
        t.simulate_keys("<C-s>f", {PaneChanged = 1}, function()
            vim.fn.timer_start(1, function()
                t.simulate_keys("<C-s>c", {PaneChanged = 1}, function()
                    vim.fn.timer_start(1, function()
                        local terminals = azul.get_terminals()
                        local term = funcs.find(function(tt) return tt.azul_win_id == 4 end, terminals)
                        t.assert(term ~= nil, "Could not find the terminal with the id 4")
                        term.azul_cmd = "ls"
                        term.azul_win_id = "with-ls"
                        terminals[#terminals].azul_win_id = "new-tab"
                        t.save_layout(file)
                        t.simulate_keys("<C-s>w", {PaneChanged = 1}, function()
                            term = azul.get_current_terminal()
                            t.single_shot('PaneChanged', function()
                                L.close_all_panes(function()
                                    t.single_shot("LayoutRestored", function()
                                        -- Need to wait for the commands to be restored
                                        -- Azul will start restoring commands after one second, so we 
                                        -- give it another 1/10 of a second extra
                                        vim.fn.timer_start(1100, function()
                                            terminals = azul.get_terminals()
                                            t.assert(#terminals == 8, "There should be in total 8 restored terminals")
                                            term = funcs.find(function(tt) return tt.azul_win_id == "with-ls" end, terminals)
                                            t.assert(term ~= nil, "Cannot find the terminal with the id with-ls")
                                            local lines = t.reverse(vim.api.nvim_buf_get_lines(term.buf, 0, -1, false))
                                            t.assert(#lines > 1, "There should be more than one line in the with-ls terminal")
                                            local ls_line = funcs.find(function(l) return l:match('ls$') end, lines)
                                            t.assert(ls_line ~= nil, "There should be a line ending in ls")
                                            azul.hide_floats()
                                            t.simulate_keys("<C-s>1", {PaneChanged = 2}, function()
                                                term = azul.get_current_terminal()
                                                t.assert(term.azul_win_id ~= "new-tab", "The first tab should not have the new-tab id")
                                                t.simulate_keys("<C-s>2", {PaneChanged = 1}, function()
                                                    term = azul.get_current_terminal()
                                                    t.assert(term.azul_win_id == "new-tab", "Second tab should have the id new-tab")
                                                    t.done()
                                                end)
                                            end)
                                        end)
                                    end)
                                    t.restore_layout(file)
                                end)
                            end)
                            vim.fn.jobstop(term.term_id)
                        end)
                    end)
                end)
            end)
        end)
    end)
end)
