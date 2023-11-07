# Azul

A nvim based terminal multiplexer. 

## Demo (tldr)

* [Azul workflow](https://cloud.taid.be/s/rkLsbJpG8kNHPXq)
* [Tmux workflow](https://cloud.taid.be/s/6nsSz6bzmcaxnoz)
* [Zellij workflow](https://cloud.taid.be/s/rCTyPcFWnn3aNCS)
* [Nested session](https://cloud.taid.be/s/76i6pKnQzperH9r)

## Install

You can install azul in several ways:

### Default

```bash
git clone https://github.com/cosminadrianpopescu/azul
cd azul
./install.sh
```

This will install azul inside the `~/.local` folder. Then, to run it, you
need to run `azul` if `~/.local/bin`, is in your path. Otherwise, you can run
directly `~/.local/bin/azul`

### Windows

```powershell
powershell.exe ./install.ps1 -prefix=c:/Users/johndoe/azul -nvimexe=c:/Users/johndoe/nvim-win64/bin/nvim-qt.exe
```

This will install azul inside `c:/Users/johndoe/azul` assuming that neovim is
installed in `c:/User/johndoe/nvim-win64`. Then, you run it like this:
`c:/Users/johndoe/azul/azul.cmd`

### Custom folder

```bash
git clone https://github.com/cosminadrianpopescu/azul
cd azul
AZUL_PREFIX=~/programs/azul ./install.sh
```

This will install `azul` in the `~/programs/azul` folder. Then, to run it,
just run `~/programs/azul/bin/azul`.

### Install in /usr/bin

```bash
git clone https://github.com/cosminadrianpopescu/azul
cd azul
AZUL_PREFIX=/usr sudo ./install.sh
```

This will install `azul` in the `/usr` folder. Then you can run it by simply
running `azul`.

*NOTE*: In case your `nvim` executable is not `nvim`, you need to specify this
when installing by using the variable `AZUL_NVIM_EXE`. For example: 

```bash
git clone https://github.com/cosminadrianpopescu/azul
cd azul
AZUL_NVIM_EXE=/opt/nvim.appimage ./install.sh
```

## Features

### Multiple workflows.

You have by default 4 types of workflows:

#### Emacs workflow

In this workflow, there are no modes and no modifiers. You are always inside
the `TERMINAL` mode. The default shortcuts are:

* `<A-c>` creates a new tab
* `<A-1>` to `<A-9>` selects the tabs from 1 to 9
* `<A-f>` creates a new floating pane
* `<A-w>` toggles floating panes visibility
* `<C-A-h>`, `<C-A-j>`, `<C-A-k>`, `<C-A-l>` - moves a floating pane left,
  down, up and right, respectively
* `<A-h>`, `<A-j>`, `<A-k>`, `<A-l>` changes a pane (floating or split) to
  left, down, up and right, respectively
* `<C-h>`, `<C-j>`, `<C-k>`, `<C-l>` creates a new split to left, down, up
  and right, respectively
* `<C-A-n>`, `<C-A-e>`, `<C-A-s>`, `<C-A-w>` moves a floating page to north
  (top), east (right), south (bottom) or left (west), respectively
* `<C-left>`, `<C-up>`, `<C-right>`, `<C-down>` resizes a floating page to the
  left, up, right or down side, respectively.
* `<A-n>` toggles nested session mode. 
* `<A-d>` disconnects the current sessison

#### Zellij workflow

In this workflow, there are modes, but there is no modifier. You will mostly
be in `TERMINAL`, `NORMAL` or the custom `azul` modes (`PANE`, `RESIZE`,
`MOVE` and `SPLIT`). 

Shortcuts for this mode:

* `<C-p>` enters `PANE` mode
* `<C-r>` enters `RESIZE` mode
* `<C-v>` enters `MOVE` mode
* `<C-s>` enters `SPLIT` mode
* `<C-T>` enters `TABS` mode
* `<esc>` goes back to `TERMINAL` mode

*`PANE` mode shortcuts*

* `c` creates new pane
* `H` go to the tab to the left
* `L` go to the tab to the right
* `w` toggles floating panes visibility
* `f` creates a new floating pane
* `h`, `j`, `k`, `l` select a pane or a split pane to the left, down, up
  or right, respectively

*`MOVE` mode shortcuts*

* `h`, `j`, `k`, `l` moves a floating pane to left, down, up or right,
  respectively.

*`SPLIT` mode shortcuts

* `h`, `j`, `k`, `l` creates a new split to left, down, up or right,
  respectively

*`RESIZE` mode shortcuts

* `h`, `j`, `k`, `l` resizes the current pane in the left, down, up or right
  direction, respectively.

* `TABS` mode shortcuts*

* `h`, `l` changes the tab to the left, right respectively
* `H`, `L` goes to the first, last tab respectively
  respectively.

#### Tmux workflow

In this workflow, you have modes and you also have a modifier. This means,
that by default you are in `TERMINAL` mode and all your keys are sent to your
`bash` interpreter (or `cmd` for windows). Whenever you want to interact with
`azul`, you need to press your modifier (by default `<C-s>`). This will put
`azul` from `TERMINAL` mode in `NORMAL` mode. Now, your key presses will be
sent to `azul`, instead of your `bash` interpreter, just like with `tmux`.

So, in order for example, to put `azul` in `PANE` mode, you have to press
`<C-s>` and then `p`

Also, here, you have the same modes as for the `zellij` workflow.

*`NORMAL` mode shortcuts*

* `c` creates new pane
* `1` to `9` selects tabs from 1 to 9
* `w` toggles floating panes visibility
* `f` creates a new floating pane
* `p` enters `PANE` mode
* `r` enters `RESIZE` mode
* `m` enters `MOVE` mode
* `s` enters `SPLIT` mode
* `T` enters `TABS` mode
* `<cr>`, `<esc>` goes back to `TERMINAL` mode

*`PANE` mode shortcuts

* `h`, `j`, `k`, `l` select a pane or a split pane to the left, down, up
  or right, respectively
* `H`, `J`, `K`, `L` splits in the left, down, right, up direction,
  respectively

*`MOVE` mode shortcuts*

* `h`, `j`, `k`, `l` moves a floating pane to left, down, up or right,
  respectively.

*`SPLIT` mode shortcuts

* `h`, `j`, `k`, `l` creates a new split to left, down, up or right,
  respectively

*`RESIZE` mode shortcuts

* `h`, `j`, `k`, `l` resizes the current pane in the left, down, up or right
  direction, respectively.

*`TABS` mode shortcuts

* `h`, `l` selects the tab previous or next
* `H`, `L` select the first or last tab

#### Azul workflow

This is the default workflow. After installation, if you don't modify your
configuration, when you will start `azul`, you will find yourself in the
`azul` workflow. This workflow is a combination of all the previous workflows.
You are all the time in the `TERMINAL` mode, you have a modifier (default
`<C-s>`) and you have modes. 

Unlike `tmux` workflow, when you click the modifier `azul` will remain in
`TERMINAL` mode, but will wait for the next key and is going to interpret it
like an `azul` command. If you wait for 300 ms, then you will also have a help
indicating what are the possible commands that you can send to `azul`.

*`TERMINAL` mode shortcuts*

* `<C-s>c` creates new pane
* `<C-s>1` to `<C-s>9` selects tabs from 1 to 9
* `<C-s>w` toggles floating panes visibility
* `<C-s>f` creates a new floating pane
* `<C-s>p` enters `PANE` mode
* `<C-s>r` enters `RESIZE` mode
* `<C-s>m` enters `MOVE` mode
* `<C-s>s` enters `SPLIT` mode
* `<C-s>T` enters `TABS` mode
* `<C-s>Ss` selects a session (linux only)
* `<C-s>St` selects a tab from the current session
* `<cr>`, `<esc>` goes back to `TERMINAL` mode

The other modes shortcuts are the same as for the `tmux` workflow shortcuts.

After the first installation, an `init.lua` file will be created in your config
folder. This will contain the `azul` workflow settings. If you want to use any
of the other workflows, overwrite this file with any of the files in the
`examples` folder. Of course, these example files are just a starting point.
You can combine the workflows and you can even create your own workflow. You
are in `vim`, so you can customize it anyway you like. 

If you want to change the workflow, you need to call `azul.set_workflow`
method. The first argument is the workflow you want to use (`tmux`, `zellij`,
`emacs` or `azul`) and the second one is the modifier (if applicable). In
order for the custom modes (`PANE`, `RESIZE`, `SPLIT` and `MOVE`) to work, you
need to use the `azul.set_key_map` function to define your keymaps. This
function takes the same arguments as `vim.api.nvim_set_keymap`.

Also, for `azul` workflow, when using `azul.set_key_map` function, keep in
mind that the shortcut that will be created will contain the modifier before.
For example, `azul.set_key_map('t', 'c', ':$tabnew<cr>', {})` is equivalent to
`vim.api.nvim_set_keymap('t', '<C-s>c', ':$tabnew<cr>')`. If you want to
create a shortcut for the terminal mode that does not contain the modifier,
you will have to use directly `vim.api.nvim_set_keymap`.

`Azul` is using the [which-key](https://github.com/folke/which-key.nvim)
plugin to show the possible actions after pressing the modifier in `TERMINAL`
mode.

### Floating panes

You can call `:lua require('azul').open_float()` to open a new float terminal
that you can then manipulate easily via special modes.

### Floating panes groups

By default, all panes are visible across all the tabs. However, whenever you
call `open_float`, `toggle_floats`, `show_floats`, `hide_floats` or
`are_floats_hidden` you can pass the group. You can create a float by calling
`open_float('group-1')` and assign it to the group `group-1`. Then, you can
show the floats of `group-1` or the floats of the `default` group. For
example, I'm using this function: 

```lua
local azul = require('azul')
local map = azul.set_key_map

local float_group = function()
    return vim.t.float_group or 'default' -- we can set on a tab the t:float_group variable and
                                          -- then all the floats on that tab
                                          -- will be assigned to the t:float_group group
end

local tab_shortcut = function(n)
    map('n', n .. '', '', {
        callback = function()
            local hidden = azul.are_floats_hidden(float_group()) -- check that the floats are displayed for the current group
            if not hidden then
                azul.hide_floats() -- hide all the floats
            end
            vim.api.nvim_command('tabn ' .. n)
            vim.api.nvim_command('startinsert')
            if not hidden then
                azul.show_floats(float_group()) -- show the floats for the current group
            end
        end
    })
end

for i = 1,9,1 do
    tab_shortcut(i)
end

map('n', 'w', '', {
    callback = function()
        azul.toggle_floats(float_group())
        vim.api.nvim_command('startinsert')
    end
})
```

So, if you set the variable `t:float_group` to a certain tab, then all the
floats opened from that terminal tab will be visible only on that tab, while
for all the others tabs, you'll see the other floats.

### Native on windows

Check out the `install.ps1` script. You can install neovim on windows, and
then run the `install.ps1` script like this:

```powershell
install.ps1 -prefix c:/Users/johndoe/azul -nvimexe c:/Users/johndoe/nvim-qt/nvim-qt.exe
```

Make sure the folder from the `prefix` parameter exists. Then you can run
`c:/Users/johndoe/azul/azul.cmd`.

I think that this is the only native windows terminal multiplexer (not
considering tmux or screen or others running under cygwin).

### Custom modes

`Azul` introduces some new modes if you need to interact with the floating
panes or with splits. You have the `Pane select` mode (`'p'`), `Float move`
mode (`'m'`), `Pane resize` mode (`'r'`), `Split` (`'s'`) mode ans `Tabs`
mode(`'T'`). 

This custom modes are built on top of the `neovim` normal or terminal mode, by
default. You can look at them as submodes of `normal` or `terminal` mode. This
means that any shortcut valid in normal that is not defined in these modes
will work also in these modes. But any shortcut defined in these modes will
have priority over the normal ones.

I use these modes because I like (as seen in the demo movie) to open a float
and then quickly position it on the screen using `hjkl` movement. Or to resize
it using `hjkl` movement. Of course, you can use some shortcuts with modifiers
for these operations (like `<C-h>` to move a float to the left and so on) and
then you don't need to use these modes. These modes are completely optional.
In order to use them, you need to use the `require('azul').set_key_map`
function instead of `vim.api.nvim_set_keymap` to set a keymap. The parameters
are identical (see the example config provided).

### Nested mode

This solves the issue of running an `azul` session inside another `azul`
session. Calling the `require('azul').toggle_nested_mode` function will toggle
the control between the 2 sessions. So, if for example you are in your main
host session, you call `toggle_nested_mode` then all the controls are passed
through the first session down to the second session. When you call the
function again, it will pass the control back to the host main session.

In order to escape back to the host main session, by default you have to press
inside the second session `<C-\><C-s>`. This is the default modifier. This
will call again `toggle_nested_mode` and it will send the control back to the
host main session.

If you want to change the escape sequence, you can pass a new escape sequence
to the initial call of the `toggle_nested_mode` function. So, for example, by
calling `require('azul').toggle_nested_mode('<C-x>')` will pass the control to
the second session (the guest `azul` session) and then, in order to pass the
control back to the host main section, you need to press `<C-x>`. This allows
you in theory to have as many nested sessions as you want.

### Infinite customizability

Remember, you are running inside a `neovim`. So, you can install any plugin,
any color scheme and you can manipulate your multiplexer in anyway allowed by
`neovim`. So, you can add any window manager that you like for handling your
floats, you can add any plugin to handle your status and you can basically do
anything that you might think of, as long as `neovim` allows it (and neovim
allows a lot...). You can even have macros, if you want, in your terminals...
How about that?

### Session support

`Azul` offers session support via `nvim` dettach feature. See `:help
--remote-ui`

When you start `azul`, you have to provide a session name. If the session is
already started, then you will be connected to that session. If not, a new
session with the indicated name will be started and you will be connected to
it. Unlike `tmux` or `zellij` or other terminal multiplexers, when
disconnecting from one session, if you are connected from several places, all
the instances will be disconnected. 

### Layout persistence

You can persist your layouts between different sessions. In order to save the
layout, you can call `require('azul').save_layout(<file-name>)`, where
`<file-name>` is the file location where the layout will be saved.

When restoring a layout (`require('azul').restore_layout(<file-name>)`), the
floats, tabs and splits are restored automatically. However, a normal simple
terminal is started in each of the restored float, tab or split. In order to
also restore an application running there, rather than trying to assume
things, `azul` will either call a callback for each of the restored float, tab
or split or it will execute anything stored in the variable `w:azul_cmd`. You
can define this callback and start whatever app was running there, like this:

```lua
local azul = require('azul')
azul.restore_layouts('/tmp/my-layout.vim', function(t, azul_win_id)
    if azul_win_id == 'vifm' then
        azul.send_to_buf(t.buf, 'vifm<cr>')
    end
end)
```

This will restore the vifm in the window identified by the id `vifm`. In order
to identify a tab, float or split after a layout reload, you can define the
variable `w:azul_win_id`, like this: `<C-s>n:let w:azul_window_id = 'vifm'`.
This will set the `azul_win_id` to the `vifm` value in the current terminal.
The value will be restored uppon a session reload.

The other way to restore an application in a saved tab, split or float: you
can define before saving the layout in any of the terminal the variable
`w:azul_cmd` like this `<C-s>n:let w:azul_cmd = "vifm"<cr>`. After saving the
layout, this variable will be saved. Upon restore, this command is executed
automatically when the terminal is opened.

Although `save_layout` calls the `vim` function `mksession`, please be aware
that the resulted file will be altered by `azul`. If you are not interested in
restoring also the application in each tab, split or float, then you can use
directly `mksession` and `source`.

## Why?

I've been a [tmux](https://github.com/tmux/tmux/wiki) user for years. Then
I've discovered [zellij](https://zellij.dev/) and been using for a few months.
They are both amazing pieces of software.

I've been using `tmux` for the obvious reasons. Then, I've switched to
`zellij` because of the floating panels and the edit back buffer in the custom
editor. The floating panels I've been searching it for years and suffered
without them in `tmux`. And then when discovering them in `zellij`, I've helped
implementing the edit in back buffer feature and this made me switch without
looking back. 

However, they both have had some minor issues that were annoying me. For
both of them, for example, changing the themes is not that straight forward
(`:colorscheme tokyonight`?). 

Copy / pasting in `tmux` is painful with the tmux buffer. I mean it was the
best solution at the time, but still... Synchronizing the terminal, vim and X
clipboard was difficult. Especially when working from tty or over ssh.

In this respect, zellij was a big step forward. Open the terminal content
inside vim and I was done. But still, it was a shortcut to press to open the
content, copy whatever was to copy and then close the editor to go back to the
terminal.

And the most annoying issue was the nested session. Open a multiplexer
session, ssh to a server and there connect to another session. I've always
fixed this by changing the modifier in the ssh session. But this raised issues
when keeping the dotfiles under git, since I have to treat this modifier in
some way to keep it under git.

`Azul` solves all this issues. It allows me to have the modal zellij workflow,
combined with the tmux modifier approach. And it solves the nested sessions
issue.

### Advantages over `tmux` or `zellij`

#### Status bar or tabline

You are inside neovim. So, you can use any plugin you want to handle the
status bar or the tabline, you can have both, you can have none, the sky (or
should I say neovim) is the limit. My status bar that you saw in the demo
video is using [lualine](https://github.com/nvim-lualine/lualine.nvim) with a
minimal configuration that you can find in the `examples` folder. But you can
choose whatever you like.

#### Very flexibile shortcuts

Again, you are in neovim. You can have whatever shortcuts neovim supports. You
can have these shortcuts inside command mode, inside terminal mode (so inside
the real terminal), in normal mode, in visual mode, you name it...

#### Nested mode

As you seen in the video, you can connect to a ssh session, press a shortcut
(in my case `<C-s>N`) and then all the keys are passed to the nested session.
To pass the control back, you press the escape shortcut `<C-\><C-s>` (this is
the default, but you can set your own) and you control again the main session.
Very neat...

### Disadvantages compared with `tmux` or `zellij`

#### Text reflow

At the moment, `neovim` supports limited text reflow of the terminals. See
[here](https://github.com/neovim/neovim/issues/2514). You can reflow the
current terminal, but only the current view (not the scrollback buffer). We'll
have to wait for this issue to be closed and then `azul` will also have proper
text reflow.

#### Cursor support

Cursor in `neovim` in terminal mode is a kind of hack. See
[here](https://github.com/neovim/neovim/issues/3681) and
[here](https://github.com/neovim/neovim/issues/3681) for more details. Until
these issues are being fixed, `azul` will have to live with the block cursor
inside its terminals. The only thing that we have in `azul` for configuring
the cursor is `:highlight TermCursor`.

If this is something that you cannot live without (having a proper cursor
inside your terminal), again, `azul` is probably not for you yet.

## Configuring

`Azul` tries to be as unopinionated as possibly. But to give you a nice start,
it will, by default, try to configure itself with the azul workflow. You'll
find inside the config folder (see bellow) an init.lua which comes from
`examples/azul.lua` and the `tokyonight`, `lualine` and `which-key` plugins
installed. You can afterwards modify these to your liking, or even delete them
and install your own if you prefer for example another status plugin than
`lualine`.

You have in the repositories 4 examples for 4 different workflows.
(`azul.lua`, `tmux.lua`, `zellij.lua` and `emacs.lua`). These files, together
with the API documentation should give you an idea of how to configure your
environment. 

If you want to install some plugins, you need to put them in your config
folder for plugins (`~/.config/azul/pack/start/` for linux or
`%AZUL_PREFIX%/.config/azul/pack/start` for windows). Of course, you can even
install there a plugin manager. The example config uses these 6 plugins: 

* [lualine](https://github.com/nvim-lualine/lualine.nvim) 
* [tokyonight](https://github.com/folke/tokyonight.nvim)
* [which-key](https://github.com/folke/which-key.nvim)
* [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
* [nvim-telescope](https://github.com/nvim-telescope/telescope.nvim)
* [bufresize](https://github.com/folke/bufresize.nvim)

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

## How it works

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

## Requirements

* `Neovim` >= 0.9, because of the floating windows title.
