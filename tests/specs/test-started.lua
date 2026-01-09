local t = require('test-env')

local channels = vim.tbl_filter(function(c) return c.mode == 'terminal' end, vim.api.nvim_list_chans())
assert(#channels == 1, 'There should be one terminal channel')
t.done()
