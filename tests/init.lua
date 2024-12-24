local t = require('test-env')

t.single_shot('PaneChanged', function()
    require('spec')
end)
