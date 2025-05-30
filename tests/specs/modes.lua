local t = require('test-env')
local azul = require('azul')
local funcs = require('functions')
local options = require('options')

-- This test case has some timeouts of 100 ms, because we need to give
-- time to bash to adjust. If this test fails and it should not, try to 
-- increate the timeout

local TIMEOUT = 250

local assert_first_line = function(what)
    local line = t.reverse(t.get_current_term_lines())[1]
    t.assert(line:match(what .. "$"), "The first line should end in " .. what)
end

vim.fn.timer_start(TIMEOUT, function()
    local lines = t.reverse(t.get_current_term_lines())
    t.assert(lines[1] ~= "", "The first line should not be empty")
    t.simulate_keys("j")
    vim.fn.timer_start(TIMEOUT, function()
        assert_first_line("j")
        local s = t.action_shortcut('enter_mode', nil, 'p') .. ' ' .. t.action_shortcut('select_down', 'p')
        t.simulate_keys(s, {ModeChanged = 1}, function()
            assert_first_line("j")
            vim.fn.timer_start(options.modifer_timeout + 10, function()
                t.simulate_keys("<esc> k", {ModeChanged = 1}, function()
                    vim.fn.timer_start(TIMEOUT, function()
                        assert_first_line("k")
                        s = t.action_shortcut('enter_mode', nil, 'T') .. ' ' .. t.action_shortcut('create_tab', 'T')
                        t.simulate_keys(s, {ModeChanged = 3, PaneChanged = 1}, function()
                            vim.fn.timer_start(TIMEOUT, function()
                                t.simulate_keys("<cr>")
                                vim.fn.timer_start(TIMEOUT, function()
                                    lines = t.reverse(t.get_current_term_lines())
                                    t.assert(lines[1] == lines[2], "The first two lines should be identical")
                                    -- Test the passthrough mode
                                    s = t.action_shortcut('enter_mode', nil, 'P')
                                    t.simulate_keys(s, {ModeChanged = 1}, function()
                                        vim.fn.timer_start(TIMEOUT, function()
                                            s = t.action_shortcut('create_tab')
                                            t.simulate_keys(s, nil, function()
                                                t.assert(#azul.get_terminals() == 2, "There should only be 2 terminals created")
                                                azul.feedkeys("<C-\\><C-s>", 't')
                                                t.simulate_keys("<cr>", {ModeChanged = 1}, function()
                                                    t.simulate_keys(s, {PaneChanged = 1}, function()
                                                        t.assert(#azul.get_terminals() == 3, "There should be now 3 terminals created")
                                                        t.done()
                                                    end)
                                                end)
                                            end)
                                        end)
                                    end)
                                end)
                            end)
                        end)
                    end)
                end)
            end)
        end)
    end)
end)

