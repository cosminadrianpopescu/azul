# Azul API

## Table of contents

* [How it works](#how-it-works)
* [API](#api)
* [Configuring via init.lua](#configuring-via-initlua)
* [Further configuration](#further-configuration)

### How it works

`Azul` is developed in `lua`, using as a renderer engine a `neovim` instance.
On top of the [neovim terminal
capabilities](https://neovim.io/doc/user/nvim_terminal_emulator.html), `azul`
will add a window management system. 

Please note that `azul` is not a `neovim` plugin. `Azul` will launch a neovim
instance, but that instance is sandboxed. It will not interfere with any
settings of another `neovim` instance that you might have on your system.
You can run `~/.local/bin/azul -l my-sesssion`, and then in the current pane
(or in any `azul` panes for that matter) you can run `nvim`. The neovim
started there will be your local `neovim`, with it's own settings.

Internally, azul uses a structure to identify each terminal running in a
pane: 

* `is_current` boolean If true, it means that this is the current terminal
* `cwd` string The current working dir
* `buf` number The corresponding nvim buffer number
* `tab_page` number The corresponding neovim tab
* `win_id` number The current neovim window id
* `term_id` number The current neovim channel id
* `win_config` table The current neovim window config. See vim.api.nvim_win_get_config()

I consider that tabs make more sense for this kind of software because of the
way vim works. In vim, each tab has a window id, like each float window or
each split. While the buffers can be displayed in a window. But the buffers
don't have a window id. 

Internally, in `azul`, every time you create a new window, a terminal is
automatically spawned in that window by calling `vim.fn.termopen`.

Because of that, is basically very easy in `azul` to just do `tabnew`, which
will create a new tab, with a new window id, so a new terminal will be
launched automatically. 

This is the prefered way in `azul`. 

Of course, being vim, nobody stops you to do `:terminal` instead of `:tabnew`.
But be carefull that this will open another terminal in the same window id.
(the current one). Internally, in azul, if you call `:lua
=require('azul').get_terminals()` you'll see that each terminal contains a
win_id field, which is not an array. This means that a buffer can only be
displayed in a window. This is why the buffers are not listed if they are not
displayed in another win_id (either in another tab or in another floating
window)

Also, you can always call `require('azul').suspend()`, to prevent the azul
events of being triggered, create your new buffer or what you need to be
created, then call `require('azul').resume()` and `require('azul').open(true,
true)`. The second parameter of `open` will force the new terminal to be
opened in the current window instead of creating a new window. If you just
call `require('azul').open()`, automatically a new tab will be generated.

### API

#### is_float

**Parameters**:

* t The terminal. 

Returns true if the terminal identified by `t` is displayed in a floating pane

#### get_current_terminal

Returns the currently selected terminal

#### hide_floats

Hides the floats if they are displayed

#### open

**Parameters**:

* start_edit If true, then starts edit automatically after the terminal is
  created (default true)
* force If true, then open the terminal without opening a new tab in the
  current place (default false)
* callback If set, then the callback will be called everytime for a new line
  in the terminal. Use it with caution, since it will accumulate memory until
  the current terminal is closed. If you set this on a currently long running
  shell, you might experience high memory consumption.

Opens a new pane with a new shell.

#### enter_mode

**Parameters**: 

* mode The `azul` mode in which to enter ('p'|'r'|'s'|'m'|'T'|'n'|'t'|'v')

Enters a new `azul` mode

#### show_floats

**Parameters**:

* group The group for which to display the floats (default 'default')
* callback A callback to be called after all the floats have been shown

Shows the floating panes of the current tab (if `link_floats_with_tabs` is set
to `true`) or of all the tabs.

#### are_floats_hidden

**Parameters**:

* group The group for which to check (optional)

Returns  true if the floats of the given group are shown, or if not if all the
floats are shown

#### open_float

**Parameters**:

* group The group for which to open a new float
* config The win_config to pass (see `vim.api.nvim_win_get_config`)

Opens a new floating pane either in the center of the screen (if not config is
passed) or at the coordonates indicated by config, for the indicated group. If
the group is missing, then the new float will be visible on all tabs.

#### toggle_floats

**Parameters**:

* group The group for which to show the floating panes

Shows the floating panes. If a given group is passed, then it shows only the
floats of the given group. 

#### feedkeys

**Parameters**:

* keys The keys to be passed
* mode The mode in which to pass the keys

Sends the given keys to the currently selected pane via
`vim.api.nvim_feedkeys`. The `mode` parameter is passed directly to
`vim.api.nvim_feedkeys`.

#### remove_key_map

**Parameters**:

* mode The mode for which to remove the keymap
* shortcut The shortcut to remove

Removes a shortcut for a given mode

#### set_key_map

**Parameters**:

* mode The mode for which to set the shortcut
* shortcut The shortcut
* rs The right side expression
* options The options to be passed. 

Sets a new shortcut for a given mode. To better understand the parameters,
check `vim.api.nvim_set_keymap`. The parameters are sent to that function.

#### get_terminals

Returns a table containing all the opened terminals.

#### move_current_float

**Parameters**:

* direction The direction in which to move (left, right, up or down)
* inc The number of rows or cols by which to move

Moves a floating pane in the specified direction by the specified increment.

#### select_pane

**Parameters**:

* buf The vim buffer number of the pane we want to select

Changed the currently selected pane to the one which contains the buffer
identified by the `buf` parameter.

#### select_next_pane

**Parameters**:

* direction The direction in which to select (left, right, up or down)
* group In case of floating panes, for in group to select

Selects the next pane in the indicated direction and for the specified group
(if `group` argument is passed)

#### current_mode

Returns the current `azul` mode.

#### send_to_buf

**Parameters**:

* buf The vim buffer number that contains the desired terminal
* data The keys to send
* escape If true, then escape the special characters, like `<cr>`

Sends the keys to the job running in the vim buffer identified by `buf`. If
`escape` is set to true, then the special characters are escaped. Instead of
`<cr>`, for example, an `enter` is sent.

#### send_to_current

**Parameters**:

* data The keys to send
* escape If true, then escape the special characters, like `<cr>`

Send the keys to the currently selected pane. If `escape` is set to true, then
the special characters are escaped. Instead of `<cr>`, for example, an `enter`
is sent.

#### split

**Parameters**:

* dir The direction in which to split (left, right up or down)

Splits the currently selected tab in the direction indicated.

#### toggle_nested_mode

**Parameters**:

* delimiter The escape sequence to pass the control back to the current
  session (default `<C-\><C-s>`)

Toggle the current session in nested mode. This means that until this function
is called again, all the keys are passed down to the terminal, to the next
`azul` session that can catch them.

#### position_current_float

**Parameters**:

* where Where to position the currently selected floating pane (top, bottom,
  start or end)

Positions the currently selected floating pane at the indicated position on
the screen.

#### redraw

Redraws the screen

#### set_workflow

**Parameters**:

* workflow The worklow to set (azul, tmux, zellij or emacs)
* modifier The modifier to use (for azul or tmux workflows, default `<C-s>`)

Changes the current workflow.

#### suspend

Suspends all `azul` events. `Azul` is overriding many neovim events. For
example, every time a new window is created (`WinNew`), a terminal is being
opened in that window. If you want to open a windows without having a terminal
opened in it, then you can call `require('azul').suspend()`. After you finish
your job, don't forget to call back `resume`. Otherwise `azul` will not work
properly.

#### resume

Resumes all `azul` events.

#### resize

**Parameters**:

* direction The direction in which to resize

Resizes an azul pane in the indicated direction. The resize is done
automatically by 5 rows or cols.

#### disconnect

Disconnects the current session.

#### save_layout

**Parameters**:

* file Where to save the given layout

#### restore_layout

**Parameters**:

* file From where to restore a layout
* callback A callback to be called everytime a pane is restored. 

Restores a given layout. 

If a callback is given, then that callback will be called with the currently
restored terminal and the win_id set via `set_win_id`. This is very usefull to
render back in your pane a certain command running before the session was
saved. 

You can create a lua script like this:

```lua
local azul = require('azul')
azul.restore_layout('~/azul-layouts/my-layout', function(terminal, azul_id)
    if azul_id == 'angular' then
        azul.send_to_buf(terminal.buf, 'cd ~/workspace/angular-project<cr>', true)
        azul.send_to_buf(terminal.buf, 'npm start serve<cr>', true)
    elseif azul_id == 'files' then
        azul.send_to_buf(terminal.buf, 'vifm<cr>', true)
    elseif azul_id == 'editor' then
        azul.send_to_buf(terminal.buf, 'cd ~/workspace/angular-project<cr>', true)
        azul.send_to_buf(terminal.buf, 'nvim', true)
    end
end)
```

Then, instead of calling `:AzulRestoreLayout`, you can switch to `AZUL` mode
and then load the file via a `luafile`, like this (assuming you saved the
previous script in `~/workspace/angular-session.lua`): 

`:luafile ~/workspace/angular-session.lua`

This will restore your layout together will all the commands that were running
in your panes.

#### set_win_id

**Parameters**:

* id The id to set for the currently selected pane

This will set the `azul` win_id. This win_id is the one that will be passed to
the previous script uppon a layout restore.

#### set_tab_variable

**Parameters**:

* key The variable name
* value The variable value

It sets a `vim` variable for the current tab. See [how it
works](#how-it-works) to see how the tabs are used by `azul`

#### set_cmd

**Parameters**:

* cmd The command to associate with the currently selected pane

This will associate the currently selected pane with a command to be ran
inside upon a restore of the layout.

#### get_current_workflow

Returns the current workflow

#### paste_from_clipboard

Pastes the content of the `+` register.

#### start_logging

**Parameters**:

* where The file location where to log the current terminal scrollback output

Starts logging the scrollback output of the current terminal to the indicated
file

#### stop_logging

If started, the logging of the current terminal is stopped.

#### toggle_passthrough

**Parameters**:

* escape The escape sequence

Toggles the passthrough mode. The escape sequence can be used to override the
default escape sequence. Can be usefull if you want to pass through to more
than one nested session. If you have 2 passed through sessions with the same
escape sequence, one inside the other, the escape sequence only applies to the
first passthrough session, not to the second. To solve this issue, you can
passthrough the second session with a different escape sequence.

### Configuring via init.lua

You'll find inside the `examples` folder 4 lua files, corresponding to each of
the workflows described above. You can use this files as a starting point for
your own `azul` configuration. You can rename the file as `init.lua` and copy
it to the config dir (by default, on `linux`, this is `~/.config/azul`).

If you want to install some plugins, you need to put them in your config
folder for plugins (`~/.config/azul/pack/start/` for linux or
`%AZUL_PREFIX%/.config/azul/pack/start` for windows). Of course, you can even
install there a plugin manager. By default, `azul` uses the following `neovim`
plugins:

* [lualine](https://github.com/nvim-lualine/lualine.nvim) 
* [which-key](https://github.com/folke/which-key.nvim)
* [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
* [nvim-telescope](https://github.com/nvim-telescope/telescope.nvim)
* [bufresize](https://github.com/folke/bufresize.nvim)

### Further configuration

If you think that the documentation is too small for a serious software, this
is because the neovim documentation is azul's documentation. I just enumerated
here what you can do with azul which is somehow different than normal nvim.
The rest is the same as nvim. For example, you want to see what the terminal
can do, you can read
[here](https://neovim.io/doc/user/nvim_terminal_emulator.html). If you want to
see the shortcuts api, you can see it
[here](https://neovim.io/doc/user/map.html). If you want to see what events
you can hook into, you can see it [here](https://neovim.io/doc/user/map.html).
And so on. I think you got the idea...

