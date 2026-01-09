local t = require('test-env')
local vesper = require('vesper')
local options = require('options')
local TABS = require('tab_vars')
local ERRORS = require('error_handling')

local get_title = function(idx)
    local id = vim.api.nvim_list_tabpages()[idx]
    return TABS.get_var(id, 'vesper_tab_title')
end

local rename_tab_keys = function()
    return t.action_shortcut('enter_mode', nil, 'T') .. ' ' .. t.action_shortcut('rename_tab', 'T')
end

assert(get_title(1) == nil, "The first terminal should have no title")
t.wait_events({UserInputPrompt = 1}, function()
    t.simulate_keys('test_1 <cr>')
end)
t.wait_events({TabTitleChanged = 1}, function()
    assert(get_title(1) == '1 test_1*', 'The first tab now should be named 1 test_1*')
    local _events = {ModeChanged = 1}
    t.wait_events(_events, function()
        local s = t.action_shortcut('create_tab')
        local events = {ModeChanged = (options.workflow == 'zellij' and 2) or 1, UserInputPrompt = 1}
        ERRORS.defer(10, function()
            t.simulate_keys(s, events, function()
                local title = get_title(2)
                assert(get_title(2) == nil, 'The second tab title should be nil not ' .. vim.inspect(title))
                t.wait_events({TabTitleChanged = 1}, function()
                    assert(get_title(1) == '1 test_1', 'The first tab now should be named 1 test_1')
                    assert(get_title(2) == '2 test_2*', 'The second tab now should be named 2 test_2*')
                    s = t.action_shortcut('enter_mode', nil, 's') .. ' ' .. t.action_shortcut('split_right', 's')
                    if options.workflow ~= 'emacs' then
                        s = s .. ' <cr>'
                    end
                    t.wait_events(_events, function()
                        t.simulate_keys(s, {PaneChanged = 1}, function()
                            events = {ModeChanged = 2}
                            if options.workflow == 'emacs' then
                                events = {ActionRan = 1}
                            end
                            t.simulate_keys(rename_tab_keys(), events, function()
                                t.wait_events({UserInput = 1}, function()
                                    ERRORS.defer(150, function()
                                        assert(get_title(1) == '1 test_1', 'Second time, the first tab now should be named 1 test_1')
                                        assert(get_title(2) == '2 test_2*', 'Second time, the second tab now should be named 2 test_2*')
                                        events = {ModeChanged = 2}
                                        if options.workflow == 'emacs' then
                                            events = {ActionRan = 1}
                                        end
                                        t.simulate_keys(rename_tab_keys(), events, function()
                                            s = '<esc> 0 e Da abc <cr>'
                                            t.simulate_keys(s, {TabTitleChanged = 1}, function()
                                                assert(get_title(1) == '1 test_1', 'Third time, the first tab now should be named 1 test_1')
                                                assert(get_title(2) == 'abc', 'Third time, the second tab now should be named abc')
                                                t.done()
                                            end)
                                        end)
                                    end)
                                end)
                                ERRORS.defer((options.workflow == 'emacs' and 150) or 1, function()
                                    vesper.feedkeys('<C-c>', 'i')
                                end)
                            end)
                        end)
                    end)
                end)
                t.simulate_keys('test_2 <cr>')
            end)
        end)
    end)
end)
