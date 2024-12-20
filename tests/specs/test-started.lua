local t = require('test-env')

local channels = vim.tbl_filter(function(c) return c.mode == 'terminal' end, vim.api.nvim_list_chans())
t.assert(#channels == 1, 'Channels expected to be 1')
t.done()
