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
* install script - *DONE*
* demo video
* tabs with own floats (that are not visible on other tabs)
* the runner - it should use the new multiplexer - *DONE*
* the disable of the modifier (for ssh) aka nested mode - *DONE*
* shortcuts to move a float up, right, bottom, left - *DONE*
* layouts
* colors from environment (so that the ssh azul has different colors) - *DONE*

## README

* don't use :terminal (bnext won't work out of the box) - how it works internally
* use open_float and tabnew - how it works internally
* explain how every time a new window is created a terminal is spawned automatically - how it works internally
* explain a bit workflow with buffers (t.win_id is not an array, so be careful when closing) - how it works internally

* my setup is for a tmux workflow - example config
* explain a zellij workflow (or emacs mode) - example config
* my config uses lualine and tokyonight plugins. You can use them or not. - example config

* at the end of the day is vim (you can install any plugin you want) - features
* session at the moment handled with something like abduco. It's comming to neovim. At that moment we won't need it. - features
* the new custom modes (you can skip using them if for example you have an emacs flow or if you use shortcuts with modifiers) - features

* next features: layouts, rotate panels - roadmap

* nvim minimum version is 0.9 because of the float window title - requirements

* advantages over classical multiplexers (very flexibile status, very flexibile shortcuts, nested_mode) - why
* disadvantages over classical multiplexers (no session, cursor issues in terminal mode) - why
