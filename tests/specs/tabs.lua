local t = require('test-env')
local azul = require('azul')

-- This test case has some timeouts of 100 ms, because we need to give
-- time to bash to adjust. If this test fails and it should not, try to 
-- increate the timeout

local TIMEOUT = 100

local assert_ls = function(state)
    for _, line in ipairs(t.get_current_term_lines()) do
        local result = line:match("ls$")
        t.assert((state and result ~= nil) or result == nil, "There should be " .. ((state and "one") or "none") .. " ls commands in this terminal")
    end
end

t.assert(#azul.get_terminals() == 1, "Initially, there should be one tab created")
t.simulate_keys("ls<cr>")
vim.fn.timer_start(TIMEOUT, function()
    assert_ls(true)
    t.single_shot("PaneChanged", function()
        vim.fn.timer_start(TIMEOUT, function()
            local lines = t.get_current_term_lines()
            t.assert(#lines > 0, "There should be at least one line of text in this terminal")
            assert_ls(false)
            t.single_shot("PaneChanged", function()
                assert_ls(true)
                t.single_shot("PaneChanged", function()
                    assert_ls(false)
                    t.single_shot("PaneChanged", function()
                        t.simulate_keys("ls<cr>")
                        vim.fn.timer_start(TIMEOUT, function()
                            assert_ls(true)
                            t.single_shot("PaneChanged", function()
                                assert_ls(false)
                                t.done()
                            end)
                            t.simulate_keys("<C-s>1")
                        end)
                    end)
                    t.simulate_keys("<C-s>c")
                end)
                t.simulate_keys("exit<cr>")
            end)
            t.simulate_keys("<C-s>1")
        end)
    end)
    t.simulate_keys("<C-s>c")
end)
