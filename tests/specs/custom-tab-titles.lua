local t = require('test-env')
local azul = require('azul')
local funcs = require('functions')
local options = require('options')

local get_title = function(idx)
    local id = vim.api.nvim_list_tabpages()[idx]
    return funcs.safe_get_tab_var(id, 'azul_tab_title')
end

local feedkeys = function(what, mode)
    if options.workflow ~= 'tmux' then
        azul.feedkeys(what, mode)
        return
    end
    vim.fn.timer_start(150, function()
        azul.feedkeys(what, mode)
    end)
end

local rename_tab_keys = function()
    return t.action_shortcut('enter_mode', nil, 'T') .. ' ' .. t.action_shortcut('rename_tab', 'T')
end

t.assert(get_title(1) == nil, "The first terminal should have no title")
funcs.log("START")
t.wait_events({TabTitleChanged = 1}, function()
    funcs.log("CREATED TAB")
    t.assert(get_title(1) == '1 test 1*', 'The first tab now should be named 1 test 1*')
    local s = t.action_shortcut('create_tab')
    local events = {ModeChanged = (options.workflow == 'zellij' and 2) or 1}
    if options.workflow == 'emacs' then
        events = {WinConfigChanged = 1}
    end
    t.simulate_keys(s, events, function()
        funcs.log("CREATED OTHER TAB")
        local title = get_title(2)
        t.assert(get_title(2) == nil, 'The second tab title should be nil not ' .. vim.inspect(title))
        t.wait_events({TabTitleChanged = 1}, function()
            funcs.log("SPLIT")
            t.assert(get_title(1) == '1 test 1', 'The first tab now should be named 1 test 1')
            t.assert(get_title(2) == '2 test 2*', 'The second tab now should be named 2 test 2*')
            s = t.action_shortcut('enter_mode', nil, 's') .. ' ' .. t.action_shortcut('split_right', 's')
            if options.workflow ~= 'emacs' then
                s = s .. ' <cr>'
            end
            t.simulate_keys(s, {PaneChanged = 1}, function()
                funcs.log("AFTER SPLIT")
                events = {ModeChanged = 2}
                if options.workflow == 'emacs' then
                    events = {ActionRan = 1}
                end
                t.simulate_keys(rename_tab_keys(), events, function()
                    funcs.log("RENAME 1")
                    t.wait_events({ModeChanged = 1}, function()
                        funcs.log("CANCEL RENAME")
                        vim.fn.timer_start(150, function()
                            funcs.log("CANCEL RENAME AFTER TIMER")
                            t.assert(get_title(1) == '1 test 1', 'Second time, the first tab now should be named 1 test 1')
                            t.assert(get_title(2) == '2 test 2*', 'Second time, the second tab now should be named 2 test 2*')
                            events = {ModeChanged = 2}
                            if options.workflow == 'emacs' then
                                events = {ActionRan = 1}
                            end
                            vim.fn.timer_start(150, function()
                                funcs.log("RENAME AGAIN")
                                t.simulate_keys(rename_tab_keys(), events, function()
                                    funcs.log("EXECUTE RENAME AGAIN")
                                    t.simulate_keys('<C-o> 0 <C-o> D', {}, function()
                                        funcs.log("RENAME DIALOG FIDDLE")
                                        t.wait_events({TabTitleChanged = 1}, function()
                                            t.assert(get_title(1) == '1 test 1', 'Third time, the first tab now should be named 1 test 1')
                                            t.assert(get_title(2) == 'abc', 'Third time, the second tab now should be named abc')
                                            funcs.log("END")
                                            t.done()
                                        end)
                                        feedkeys('abc<cr>', 'i')
                                    end)
                                end)
                            end)
                        end)
                    end)
                    vim.fn.timer_start((options.workflow == 'emacs' and 150) or 1, function()
                        funcs.log("FEED C-c")
                        azul.feedkeys('<C-c>', 'i')
                    end)
                end)
            end)
        end)
        feedkeys('test 2<cr>', 'i')
    end)
end)
t.single_shot('AzulStarted', function()
    vim.fn.timer_start(500, function()
        azul.feedkeys('test 1<cr>', 'i')
    end)
end)
