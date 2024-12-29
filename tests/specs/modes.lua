local t = require('test-env')
local azul = require('azul')
local cfg = require('config')

-- This test case has some timeouts of 100 ms, because we need to give
-- time to bash to adjust. If this test fails and it should not, try to 
-- increate the timeout

local TIMEOUT = 150

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
        t.simulate_keys("<C-s>pk", {ModeChanged = 1}, function()
            assert_first_line("j")
            vim.fn.timer_start(cfg.default_config.options.modifer_timeout + 10, function()
                t.simulate_keys("<esc>k", {ModeChanged = 1}, function()
                    vim.fn.timer_start(TIMEOUT, function()
                        assert_first_line("k")
                        t.simulate_keys("<C-s>Tc", {ModeChanged = 4, PaneChanged = 1}, function()
                            vim.fn.timer_start(TIMEOUT, function()
                                t.simulate_keys("<cr>")
                                vim.fn.timer_start(TIMEOUT, function()
                                    lines = t.reverse(t.get_current_term_lines())
                                    t.assert(lines[1] == lines[2], "The first two lines should be identical")
                                    -- Test the passthrough mode
                                    t.simulate_keys("<C-s>N", {ModeChanged = 1}, function()
                                        vim.fn.timer_start(TIMEOUT, function()
                                            t.simulate_keys("<C-s>c", nil, function()
                                                t.assert(#azul.get_terminals() == 2, "There should only be 2 terminals created")
                                                azul.feedkeys("<C-\\><C-s>", 't')
                                                t.simulate_keys("<cr>", {ModeChanged = 1}, function()
                                                    t.simulate_keys("<C-s>c", {PaneChanged = 1}, function()
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

