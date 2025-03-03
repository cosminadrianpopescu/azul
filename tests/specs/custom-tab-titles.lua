local t = require('test-env')
local azul = require('azul')
local funcs = require('functions')

local get_title = function(idx)
    local id = vim.api.nvim_list_tabpages()[idx]
    return funcs.safe_get_tab_var(id, 'azul_tab_title')
end

t.assert(get_title(1) == nil, "The first terminal should have no title")
t.single_shot('TabTitleChanged', function()
    t.assert(get_title(1) == '1 test 1*', 'The first tab now should be named 1 test 1*')
    t.simulate_keys('<C-s>c', {ModeChanged = 2}, function()
        local title = get_title(2)
        t.assert(get_title(2) == nil, 'The second tab title should be nil not ' .. vim.inspect(title))
        t.single_shot('TabTitleChanged', function()
            t.assert(get_title(1) == '1 test 1', 'The first tab now should be named 1 test 1')
            t.assert(get_title(2) == '2 test 2*', 'The second tab now should be named 2 test 2*')
            t.simulate_keys('<C-s>sl<cr><C-s>n', {ModeChanged = 3}, function()
                t.wait_events({ModeChanged = 3}, function()
                    t.wait_events({ModeChanged = 2}, function()
                        t.assert(get_title(1) == '1 test 1', 'Second time, the first tab now should be named 1 test 1')
                        t.assert(get_title(2) == '2 test 2*', 'Second time, the second tab now should be named 2 test 2*')
                        t.simulate_keys('<C-s>n', {ModeChanged = 1}, function()
                            t.wait_events({ModeChanged = 3}, function()
                                t.wait_events({ModeChanged = 2}, function()
                                    t.wait_events({TabTitleChanged = 1}, function()
                                        t.assert(get_title(1) == '1 test 1', 'Third time, the first tab now should be named 1 test 1')
                                        t.assert(get_title(2) == 'abc', 'Third time, the second tab now should be named abc')
                                        t.done()
                                    end)
                                    azul.feedkeys('abc<cr>', 'i')
                                end)
                                azul.feedkeys('<esc>Da', 'i')
                            end)
                            azul.feedkeys(':AzulRenameCurrentTab<cr>', 'i')
                        end)
                    end)
                    azul.feedkeys('<C-c>', 'i')
                end)
                azul.feedkeys(':AzulRenameCurrentTab<cr>', 't')
            end)
        end)
        azul.feedkeys('test 2<cr>', 'i')
    end)
end)
t.single_shot('AzulStarted', function()
    vim.fn.timer_start(500, function()
        azul.feedkeys('test 1<cr>', 'i')
    end)
end)
