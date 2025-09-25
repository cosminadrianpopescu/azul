local t = require('test-env')
local azul = require('azul')
local funcs = require('functions')
local options = require('options')

local L = {}
local TIMEOUT = 150

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

local tab_shortcut = function(which)
    local pref = ''
    if options.workflow == 'zellij' then
        pref = t.action_shortcut('enter_mode', nil, 'T') .. ' '
    end
    return pref .. t.action_shortcut('tab_select' .. ((options.workflow == 'zellij' and '_first') or ''), (options.workflow == 'zellij' and 'T') or nil, (options.workflow ~= 'zellij' and which) or nil)
end

local second_tab_shortcut = function()
    local result = tab_shortcut('2')
    if options.workflow ~= 'zellij' then
        return result
    end
    return result .. ' ' .. t.action_shortcut('tab_select_next', 'T')
end

local x = t.action_shortcut('split_down', 's') .. ' '
local s = t.action_shortcut('enter_mode', nil, 's') .. ' '
    .. t.action_shortcut('split_right', 's') .. ' ' .. x .. x
    .. t.action_shortcut('split_left', 's') .. ' ' .. t.action_shortcut('split_up', 's')

t.wait_events({TabTitleChanged = 1}, function()
    t.simulate_keys(s, {PaneChanged = 5}, function()
        local events = {ModeChanged = 1}
        if options.workflow == 'emacs' then
            events = nil
        end
        t.simulate_keys("<cr>", events, function()
            t.simulate_keys(t.action_shortcut('create_float'), {PaneChanged = 1}, function()
                vim.fn.timer_start(1, function()
                    t.simulate_keys(t.action_shortcut('create_tab'), {PaneChanged = 1}, function()
                        vim.fn.timer_start(1, function()
                            local terminals = azul.get_terminals()
                            local term = funcs.find(function(tt) return tt.azul_win_id == 4 end, terminals)
                            t.assert(term ~= nil, "Could not find the terminal with the id 4")
                            term.azul_cmd = "ls"
                            term.azul_win_id = "with-ls"
                            terminals[#terminals].azul_win_id = "new-tab"
                            t.save_layout(file)
                            vim.fn.timer_start(TIMEOUT, function()
                                t.simulate_keys(t.action_shortcut('toggle_floats'), {PaneChanged = 1}, function()
                                    term = azul.get_current_terminal()
                                    t.single_shot('PaneChanged', function()
                                        L.close_all_panes(function()
                                            t.single_shot("LayoutRestored", function()
                                                -- Need to wait for the commands to be restored
                                                -- Azul will start restoring commands after one second, so we 
                                                -- give it another 2 seconds extra
                                                vim.fn.timer_start(3000, function()
                                                    terminals = azul.get_terminals()
                                                    t.assert(#terminals == 8, "There should be in total 8 restored terminals")
                                                    term = funcs.find(function(tt) return tt.azul_win_id == "with-ls" end, terminals)
                                                    t.assert(term ~= nil, "Cannot find the terminal with the id with-ls")
                                                    local lines = funcs.reverse(vim.api.nvim_buf_get_lines(term.buf, 0, -1, false))
                                                    t.assert(#lines > 1, "There should be more than one line in the with-ls terminal")
                                                    local ls_line = funcs.find(function(l) return l:match('ls$') end, lines)
                                                    t.assert(ls_line ~= nil, "There should be a line ending in ls")
                                                    azul.hide_floats()
                                                    vim.fn.timer_start(100, function()
                                                        t.simulate_keys(tab_shortcut('1'), {PaneChanged = 1}, function()
                                                            term = azul.get_current_terminal()
                                                            t.assert(term.azul_win_id ~= "new-tab", "The first tab should not have the new-tab id")
                                                            t.simulate_keys(second_tab_shortcut(), {PaneChanged = 1}, function()
                                                                term = azul.get_current_terminal()
                                                                t.assert(term.azul_win_id == "new-tab", "Second tab should have the id new-tab")
                                                                t.done()
                                                            end)
                                                        end)
                                                    end)
                                                end)
                                            end)
                                            vim.defer_fn(function()
                                                t.restore_layout(file)
                                            end, 1)
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
    end)
end)
