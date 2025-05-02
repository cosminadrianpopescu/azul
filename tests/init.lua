local funcs = require('functions')

if funcs.is_marionette() then
    return
end

local t = require('test-env')

t.single_shot('AzulStarted', function()
    require('spec')
end)
