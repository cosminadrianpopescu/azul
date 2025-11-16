local t = require('test-env')
local vesper = require('vesper')
local options = require('options')

t.wait_events({TabTitleChanged = 1}, function()
    local s = t.action_shortcut('create_tab')
    t.simulate_keys(s, {PaneChanged = 1}, function()
    end)
end)
