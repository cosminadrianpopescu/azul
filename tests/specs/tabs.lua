local t = require('test-env')
local vesper = require('vesper')
local funcs = require('functions')
local options = require('options')
local ERRORS = require('error_handling')

-- This test case has some timeouts of 100 ms, because we need to give
-- time to bash to adjust. If this test fails and it should not, try to 
-- increate the timeout

local TIMEOUT = 150

local assert_ls = function(state)
    for _, line in ipairs(t.get_current_term_lines()) do
        local result = line:match("ls$")
        t.assert((state and result ~= nil) or result == nil, "There should be " .. ((state and "one") or "none") .. " ls commands in this terminal")
    end
end

local first_tab_shortcut = function()
    local pref = ''
    if options.workflow == 'zellij' then
        pref = t.action_shortcut('enter_mode', nil, 'T')
    end
    return pref .. ' ' .. t.action_shortcut('tab_select' .. ((options.workflow == 'zellij' and '_previous') or ''), (options.workflow == 'zellij' and 'T') or nil, (options.workflow ~= 'zellij' and '1') or nil)
end

t.assert(#vesper.get_terminals() == 1, "Initially, there should be one tab created")
t.wait_events({TabTitleChanged = 1}, function()
    vesper.feedkeys('ls<cr>', 't')
    ERRORS.defer(TIMEOUT, function()
        assert_ls(true)
        local s = t.action_shortcut('create_tab')
        t.simulate_keys(s, {PaneChanged = 1}, function()
            local lines = t.get_current_term_lines()
            t.assert(#lines > 0, "There should be at least one line of text in this terminal")
            assert_ls(false)
            t.simulate_keys(first_tab_shortcut(), {PaneChanged = 1}, function()
                assert_ls(true)
                local term = vesper.get_current_terminal()
                t.single_shot('PaneChanged', function()
                    assert_ls(false)
                    if options.workflow == 'tmux' and (vesper.current_mode() == 'n' or vesper.current_mode() == 'a') then
                        vesper.feedkeys('i', 'n')
                    end
                    s = t.action_shortcut('create_tab')
                    ERRORS.defer(TIMEOUT, function()
                        t.simulate_keys(s, {PaneChanged = 1}, function()
                            vesper.feedkeys("ls<cr>", 't')
                            ERRORS.defer(TIMEOUT, function()
                                assert_ls(true)
                                t.simulate_keys(first_tab_shortcut(), {PaneChanged = 1}, function()
                                    assert_ls(false)
                                    t.done()
                                end)
                            end)
                        end)
                    end)
                end)
                vim.fn.jobstop(term.term_id)
            end)
        end)
    end)
end)
