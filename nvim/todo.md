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

* try on windows
* install script
* demo video
* tabs with own floats (that are not visible on other tabs)
* the runner - it should use the new multiplexer - *DONE*
* the disable of the modifier (for ssh) aka nested mode - *DONE*
* shortcuts to move a float up, right, bottom, left
* layouts

## README

* don't use :terminal (bnext won't work out of the box)
* use open_float and tabnew
* explain how every time a new window is created a terminal is spawned automatically
* my setup is for a tmux workflow
* explain a zellij workflow (or emacs mode)
* at the end of the day is vim (you can install any plugin you want)
* my config uses lualine and tokyonight plugins. You can use them or not.
* if you want a workflow with buffers, you have to list them yourself (difficult without modifying the source code)
* next features: layouts, rotate panels
* session at the moment handled with something like abduco. It's comming to neovim. At that moment we won't need it.
* nvim minimum version is 0.9 because of the float window title
* no vimscript. only lua. 
* the new custom modes (you can skip using them if for example you have an emacs flow or if you use shortcuts with modifiers)
* advantages over classical multiplexers (very flexibile status, very flexibile shortcuts, nested_mode)
* disadvantages over classical multiplexers (no session, cursor issues in terminal mode)
