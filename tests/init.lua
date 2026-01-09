local funcs = require('functions')
local ERRORS = require('error_handling')

if funcs.is_marionette() then
    return
end

local t = require('test-env')

ERRORS.on_unhandled_error(function(err)
    t.assert(false, err)
end)

t.single_shot('VesperStarted', function()
    require('spec')
end)
