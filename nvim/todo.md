* it should start directly in term mode with a new term - *DONE*

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
``` - *DONE*

* The function set_key_map will take just check the mode. If the mode is 'p' (pane mode) will do custom things. If the mode is not p, is just going to pass all arguments to the vim.api.nvim_set_key_map function. - *DONE*

* try on windows - *DONE*
* install script - *DONE*
* demo video - *DONE*
* tabs with own floats (that are not visible on other tabs) - *DONE*
* the runner - it should use the new multiplexer - *DONE*
* the disable of the modifier (for ssh) aka nested mode - *DONE*
* shortcuts to move a float up, right, bottom, left - *DONE*
* layouts - *DONE*
* colors from environment (so that the ssh vesper has different colors) - *DONE*

## README

* don't use :terminal (bnext won't work out of the box) - how it works internally - *DONE*
* use open_float and tabnew - how it works internally - *DONE*
* explain how every time a new window is created a terminal is spawned automatically - how it works internally - *DONE*
* explain a bit workflow with buffers (t.win_id is not an array, so be careful when closing) - how it works internally - *DONE*

* my setup is for a tmux workflow - example config - *DONE*
* explain a zellij workflow (or emacs mode) - example config - *DONE*
* my config uses lualine and tokyonight plugins. You can use them or not. - example config - *DONE*

* at the end of the day is vim (you can install any plugin you want) - features - *DONE*
* session at the moment handled with something like abduco. It's comming to neovim. At that moment we won't need it. - features - *DONE*
* the new custom modes (you can skip using them if for example you have an emacs flow or if you use shortcuts with modifiers) - features - *DONE*

* next features: layouts, rotate panels - roadmap

* nvim minimum version is 0.9 because of the float window title - requirements - *DONE*

* advantages over classical multiplexers (very flexibile status, very flexibile shortcuts, nested_mode) - why - *DONE*
* disadvantages over classical multiplexers (cursor issues in terminal mode) - why - *DONE*

* standardize the status line and the other plugins - *DONE*
* extract the configs and put a ini or kdf or yaml layer in between, so other people than nvim devs can use it and configure it - *DONE*
* there should be a config.lua that should enumerate the config options - *DONE*
* document the public lua API, so that advanced users can really customize it - *DONE*
* create separate doc pages for api.md, config.md and the README.md - *DONE*
* expose the vesper api and the shortcuts as vim commands - *DONE*
* copy / paste shotrtcuts - *DONE*
* visual mode shortcuts
* save session and resurect session shortcuts and commands
* install vim.ui to ask for files.

* group shortcuts together by action
* sort by action rather than shortcut
* show first 2 rows of shortcuts and then have a shortcut to see all.

* option use_default_statusbar
* option to automatically start logging

* cheatsheet test case
* mappings.lua need to treat the case of <C-s><C-s> by itself

* when opening a float, instead of relying on the WinEnter, just open it with the buffer directly (this will help us with the start_insert)
