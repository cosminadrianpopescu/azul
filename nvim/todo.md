* it should start directly in term mode with a new term

## Mappings:

```lua
local f = require('nvim-multiplexer').set_key_map
f('t', '<c-s>', '<C-\\><C-n>', {})
f('n', '1', '', {
    callback = function() require('nvim-multiplexer').go_to_tab(1) end
})
f('p', 'h', '', {
    callback = function() require('nvim-multiplexer').select_next_pane() end
})
```

* The function set_key_map will take just check the mode. If the mode is 'p' (pane mode) will do custom things. If the mode is not p, is just going to pass all arguments to the vim.api.nvim_set_key_map function.
